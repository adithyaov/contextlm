module Main (main) where

import System.Directory (createDirectoryIfMissing)
import System.Environment (getArgs)
import System.Exit (exitFailure)

import qualified Streamly.Console.Stdio as Stdio
import qualified Streamly.Data.Stream as Stream

import Cli (parseArgs, usage)
import FileSystem (createContextFS)
import Types

main :: IO ()
main = do
  args <- getArgs
  case parseArgs args of
    Left err -> do
      putStrLn $ "Error: " ++ err
      putStrLn ""
      putStrLn usage
      exitFailure
    Right cmd -> runCommand cmd

runCommand :: Command -> IO ()
runCommand (CreateContextCmd args) =
  Stream.fold Stdio.writeChunks $ createContextFS (dir args) (filterRules args)
runCommand (CloneCmd args) = do
  createDirectoryIfMissing True (cloneDir args)
  gitCloneTo (cloneGitSource args) (cloneDir args)
