module Main (main) where

import System.Environment (getArgs)
import System.Exit (exitFailure)

import Cli (parseArgs, usage)

main :: IO ()
main = do
  args <- getArgs
  case parseArgs args of
    Left err -> do
      putStrLn $ "Error: " ++ err
      putStrLn ""
      putStrLn usage
      exitFailure
    Right cmd -> print cmd
