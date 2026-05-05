{-# LANGUAGE QuasiQuotes #-}

module FileSystem (createContextFS) where

import Data.Char (ord)
import Data.Function ((&))
import Data.Word (Word8)
import qualified Streamly.Data.Array as Array
import Streamly.Data.Stream (Stream)
import qualified Streamly.Data.Stream as Stream
import Streamly.Data.Unfold (Unfold)
import qualified Streamly.FileSystem.FileIO as FileIO
import Streamly.FileSystem.Path (Path)
import qualified Streamly.FileSystem.Path as Path
import qualified Streamly.Internal.Data.Stream as IStream
import qualified Streamly.Internal.Data.Unfold as IUnfold
import qualified Streamly.Internal.FileSystem.DirIO as Dir
import Streamly.Unicode.String (str)
import System.FilePath (makeRelative)
import System.FilePath.Glob (Pattern, compile, match)

import Types

-- Filtering

applyRules :: [FilterRule Pattern] -> FilePath -> Bool
applyRules rules path = foldl apply False rules
  where
    apply current (Include glob) = if match glob path then True else current
    apply current (Exclude glob) = if match glob path then False else current

unfoldDir :: (Dir.ReadOptions -> Dir.ReadOptions) -> Unfold IO (Either Path b) (Either Path Path)
unfoldDir f = IUnfold.either (Dir.eitherReaderPaths f) IUnfold.nil

getFilteredPaths :: Path -> [FilterRule String] -> IO [Path]
getFilteredPaths dirRoot rules =
    Stream.fromPure (Left dirRoot)
        & IStream.unfoldIterate (unfoldDir id)
        & Stream.mapMaybe keepFile
        & Stream.toList
  where
    dirRootLen = length $ Path.toString dirRoot
    rulesGlobList = fmap compile <$> rules
    keepFile (Left _) = Nothing
    keepFile (Right p) =
        if applyRules rulesGlobList $ drop (dirRootLen + 1) $ Path.toString p
            then Just p
            else Nothing

-- Streaming

streamFilePath :: Path -> Stream IO (Array.Array Word8)
streamFilePath = FileIO.readChunks

bytesOf :: String -> Stream IO (Array.Array Word8)
bytesOf s = Stream.fromPure $ Array.fromList $ map (fromIntegral . ord) s

wrapFile :: Path -> Path -> Stream IO (Array.Array Word8)
wrapFile dirRoot path =
    bytesOf openTag
        `Stream.append` streamFilePath path
        `Stream.append` bytesOf "\n</contextlm>\n"
  where
    relPath = makeRelative (Path.toString dirRoot) (Path.toString path)
    openTag = [str|<contextlm path="#{relPath}">|] ++ "\n"

createContextFS :: FilePath -> [FilterRule String] -> Stream IO (Array.Array Word8)
createContextFS dirRoot0 rules =
    Stream.concatMap body $ Stream.fromEffect setup
  where
    setup = do
        dirRoot <- Path.fromString dirRoot0
        paths <- getFilteredPaths dirRoot rules
        return (dirRoot, paths)

    body (dirRoot, paths) =
        Stream.concatMap (wrapFile dirRoot) (Stream.fromList paths)
