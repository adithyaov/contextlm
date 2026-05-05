{-# LANGUAGE OverloadedStrings #-}

module Serve (serve) where

import Control.Exception (SomeException, try)
import Control.Monad (unless)
import Data.Aeson (FromJSON (..), ToJSON (..), object, withObject, (.:), (.=))
import qualified Data.Text.Lazy as TL
import Data.Word (Word8)
import Network.HTTP.Types (status400, status500)
import Data.Maybe (fromMaybe)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, listDirectory)
import System.Environment (lookupEnv)
import System.FilePath (dropExtension, takeFileName, (</>))
import Web.Scotty

import qualified Streamly.Data.Array as Array
import qualified Streamly.Data.Fold as Fold
import qualified Streamly.Data.Stream as Stream
import qualified Streamly.FileSystem.FileIO as FileIO
import qualified Streamly.FileSystem.Path as Path

import FileSystem (createContextFS)
import Types (FilterRule (..), GitSource (..), ServeArgs (..), gitCloneTo)

-- ── Tree ─────────────────────────────────────────────────────────────────────

data TreeNode
    = FileNode String String -- name, relPath
    | DirNode String String [TreeNode] -- name, relPath, children

instance ToJSON TreeNode where
    toJSON (FileNode name path) =
        object
            ["name" .= name, "type" .= ("file" :: String), "path" .= path]
    toJSON (DirNode name path children) =
        object
            [ "name" .= name
            , "type" .= ("dir" :: String)
            , "path" .= path
            , "children" .= children
            ]

buildTree :: FilePath -> IO TreeNode
buildTree root = DirNode (takeFileName root) "" <$> buildChildren root ""

buildChildren :: FilePath -> FilePath -> IO [TreeNode]
buildChildren root rel = do
    let absDir = if null rel then root else root </> rel
    names <- listDirectory absDir
    mapM (buildEntry root rel) names

buildEntry :: FilePath -> FilePath -> FilePath -> IO TreeNode
buildEntry root rel name = do
    let rel' = if null rel then name else rel </> name
    isDir <- doesDirectoryExist (root </> rel')
    if isDir
        then DirNode name rel' <$> buildChildren root rel'
        else return $ FileNode name rel'

-- ── Append ───────────────────────────────────────────────────────────────────

data FileEntry = FileEntry {feDir :: String, fePath :: String}

instance FromJSON FileEntry where
    parseJSON = withObject "FileEntry" $ \o ->
        FileEntry <$> o .: "dir" <*> o .: "path"

data AppendRequest = AppendRequest
    { arEntries :: [FileEntry]
    , arOutput :: String
    }

instance FromJSON AppendRequest where
    parseJSON = withObject "AppendRequest" $ \o ->
        AppendRequest <$> o .: "entries" <*> o .: "output"

data AppendResponse = AppendResponse {appended :: Int, bytes :: Int}

instance ToJSON AppendResponse where
    toJSON r = object ["appended" .= appended r, "bytes" .= bytes r]

countBytes :: (Monad m) => Fold.Fold m (Array.Array Word8) Int
countBytes = Fold.foldl' (\acc arr -> acc + Array.length arr) 0

fileEntryToPath :: FileEntry -> FilePath
fileEntryToPath e = feDir e </> fePath e

writeContext :: [FileEntry] -> FilePath -> IO (Int, Int)
writeContext entries outputFile = do
    outputPath <- Path.fromString outputFile
    let chunks = createContextFS "." (map (Include . fileEntryToPath) entries)
    (_, total) <- Stream.fold (Fold.tee (FileIO.writeChunks outputPath) countBytes) chunks
    return (length entries, total)

-- ── Clone ─────────────────────────────────────────────────────────────────────

data CloneRequest = CloneRequest {crUrl :: String}

instance FromJSON CloneRequest where
    parseJSON = withObject "CloneRequest" $ \o -> CloneRequest <$> o .: "url"

data CloneResponse = CloneResponse {clDir :: String, clTree :: TreeNode}

instance ToJSON CloneResponse where
    toJSON r = object ["dir" .= clDir r, "tree" .= clTree r]

repoName :: String -> String
repoName = dropExtension . takeFileName

cloneIfNeeded :: FilePath -> String -> IO FilePath
cloneIfNeeded reposDir url = do
    let dest = reposDir </> repoName url
    exists <- doesDirectoryExist dest
    unless exists $ gitCloneTo (GitSource url) dest
    return dest

cloneAndBuildTree :: FilePath -> String -> IO (FilePath, TreeNode)
cloneAndBuildTree reposDir url = do
    dest <- cloneIfNeeded reposDir url
    tree <- buildTree dest
    return (dest, tree)

-- ── Server ───────────────────────────────────────────────────────────────────

serve :: ServeArgs -> IO ()
serve args = do
    webDir <- fromMaybe "web" <$> lookupEnv "CONTEXTLM_WEB_DIR"
    createDirectoryIfMissing True (serveReposDir args)
    scotty (servePort args) $ do
        -- Static files
        get "/" $ do
            setHeader "Content-Type" "text/html; charset=utf-8"
            file (webDir </> "index.html")

        get "/style.css" $ do
            setHeader "Content-Type" "text/css; charset=utf-8"
            file (webDir </> "style.css")

        get "/mithril.min.js" $ serveJs (webDir </> "mithril.min.js")
        get "/utils.js" $ serveJs (webDir </> "utils.js")
        get "/dummy.js" $ serveJs (webDir </> "dummy.js")
        get "/live.js"  $ serveJs (webDir </> "live.js")
        get "/app.js"   $ serveJs (webDir </> "app.js")

        -- GET /api/tree?dir=<path>
        get "/api/tree" $ do
            dir <- queryParam "dir"
            exists <- liftIO $ doesDirectoryExist dir
            if not exists
                then do
                    status status400
                    text $ "Directory not found: " <> TL.pack dir
                else do
                    result <- liftIO (try (buildTree dir) :: IO (Either SomeException TreeNode))
                    case result of
                        Left e -> do status status500; text (TL.pack $ show e)
                        Right tree -> json tree

        -- POST /api/clone  { url }
        post "/api/clone" $ do
            req <- jsonData
            result <-
                liftIO
                    ( try (cloneAndBuildTree (serveReposDir args) (crUrl req)) ::
                        IO (Either SomeException (FilePath, TreeNode))
                    )
            case result of
                Left e -> do status status500; text (TL.pack $ show e)
                Right (dest, tree) -> json $ CloneResponse dest tree

        -- POST /api/context/append  { entries: [{dir, path}], output }
        post "/api/context/append" $ do
            req <- jsonData
            result <-
                liftIO
                    ( try (writeContext (arEntries req) (arOutput req)) ::
                        IO (Either SomeException (Int, Int))
                    )
            case result of
                Left e -> do status status500; text (TL.pack $ show e)
                Right (n, total) -> json $ AppendResponse n total

serveJs :: FilePath -> ActionM ()
serveJs path = do
    setHeader "Content-Type" "application/javascript; charset=utf-8"
    file path
