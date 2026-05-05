module Cli (parseArgs, usage) where

import Types

type ParseError = String

parseArgs :: [String] -> Either ParseError Command
parseArgs args = do
  rest0           <- expectFlag "--action" args
  (action, rest1) <- parseAction rest0
  case action of
    AddContext -> AddContextCmd <$> parseAddContextArgs rest1

parseAddContextArgs :: [String] -> Either ParseError AddContextArgs
parseAddContextArgs args = do
  rest0           <- expectFlag "--out" args
  (out,    rest1) <- takeValue "--out" rest0
  rest2           <- expectFlag "--title" rest1
  (ttl,    rest3) <- takeValue "--title" rest2
  (src,    rest4) <- parseContextSource rest3
  rules           <- parseFilterRules rest4
  pure $ AddContextArgs out ttl src (CFFileSystemFilter rules)

expectFlag :: String -> [String] -> Either ParseError [String]
expectFlag flag []     = Left $ "Expected '" ++ flag ++ "' but reached end of arguments"
expectFlag flag (x:xs)
  | x == flag = Right xs
  | otherwise = Left $ "Expected '" ++ flag ++ "' but got '" ++ x ++ "'"

takeValue :: String -> [String] -> Either ParseError (String, [String])
takeValue flag []     = Left $ "Expected value after '" ++ flag ++ "' but reached end of arguments"
takeValue _    (x:xs) = Right (x, xs)

parseAction :: [String] -> Either ParseError (Action, [String])
parseAction []                   = Left "Expected action value but reached end of arguments"
parseAction ("add-context":rest) = Right (AddContext, rest)
parseAction (x:_)                = Left $ "Unknown action '" ++ x ++ "' (expected: add-context)"

parseContextSource :: [String] -> Either ParseError (ContextSource, [String])
parseContextSource args = do
  rest0         <- expectFlag "--source" args
  (src, rest1)  <- takeValue "--source" rest0
  case src of
    "git" -> do
      rest2      <- expectFlag "--url" rest1
      (u, rest3) <- takeValue "--url" rest2
      pure (CSGitSource (GitSource u), rest3)
    _ -> Left $ "Unknown source '" ++ src ++ "' (expected: git)"

parseFilterRules :: [String] -> Either ParseError [FilterRule]
parseFilterRules []                      = Right []
parseFilterRules ("--include":glob:rest) = (Include glob :) <$> parseFilterRules rest
parseFilterRules ("--exclude":glob:rest) = (Exclude glob :) <$> parseFilterRules rest
parseFilterRules ("--include":_)         = Left "'--include' requires a glob pattern"
parseFilterRules ("--exclude":_)         = Left "'--exclude' requires a glob pattern"
parseFilterRules (x:_)                   = Left $ "Unexpected argument '" ++ x ++ "'"

usage :: String
usage = unlines
  [ "Usage:"
  , "  contextlm --action add-context"
  , "            --out <file>"
  , "            --title <title>"
  , "            --source git"
  , "            --url <url>"
  , "            [--include <glob> | --exclude <glob>] ..."
  , ""
  , "Arguments must appear in the order shown above."
  ]
