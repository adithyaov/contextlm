{-# LANGUAGE QuasiQuotes #-}

module Types where

import qualified Streamly.System.Command as Command
import Streamly.Unicode.String (str)

logCmd :: String -> IO ()
logCmd cmd = putStrLn [str|$ #{cmd}|]

runCmd :: String -> IO ()
runCmd cmd = do
    logCmd cmd
    Command.toStdout cmd

gitCloneTo :: GitSource -> FilePath -> IO ()
gitCloneTo gitSource dest =
    let url = gsUrl gitSource
     in runCmd [str|git clone #{url} #{dest}|]

-- Data types

data Action = CreateContext | Clone deriving (Show, Eq)

data GitSource = GitSource
    { gsUrl :: String
    }
    deriving (Show, Eq)

data FilterRule a = Include a | Exclude a deriving (Show, Eq)

instance Functor FilterRule where
    fmap f (Include a) = Include (f a)
    fmap f (Exclude a) = Exclude (f a)

data CreateContextArgs = CreateContextArgs
    { dir :: FilePath
    , filterRules :: [FilterRule String]
    }
    deriving (Show, Eq)

data CloneArgs = CloneArgs
    { cloneGitSource :: GitSource
    , cloneDir :: FilePath
    }
    deriving (Show, Eq)

data Command
    = CreateContextCmd CreateContextArgs
    | CloneCmd CloneArgs
    deriving (Show, Eq)
