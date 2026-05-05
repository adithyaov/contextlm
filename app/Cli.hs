module Cli (parseArgs, usage) where

import Types

type ParseError = String

parseArgs :: [String] -> Either ParseError Command
parseArgs args = do
    rest0 <- expectFlag "--action" args
    (action, rest1) <- parseAction rest0
    case action of
        CreateContext -> CreateContextCmd <$> parseCreateContextArgs rest1
        Clone -> CloneCmd <$> parseCloneArgs rest1
        Serve -> ServeCmd <$> parseServeArgs rest1

parseCreateContextArgs :: [String] -> Either ParseError CreateContextArgs
parseCreateContextArgs args = do
    rest0 <- expectFlag "--dir" args
    (d, rest1) <- takeValue "--dir" rest0
    rules <- parseFilterRules rest1
    pure $ CreateContextArgs d rules

parseCloneArgs :: [String] -> Either ParseError CloneArgs
parseCloneArgs args = do
    rest0 <- expectFlag "--url" args
    (u, rest1) <- takeValue "--url" rest0
    rest2 <- expectFlag "--dir" rest1
    (d, rest3) <- takeValue "--dir" rest2
    case rest3 of
        [] -> pure $ CloneArgs (GitSource u) d
        (x : _) -> Left $ "Unexpected argument '" ++ x ++ "'"

expectFlag :: String -> [String] -> Either ParseError [String]
expectFlag flag [] = Left $ "Expected '" ++ flag ++ "' but reached end of arguments"
expectFlag flag (x : xs)
    | x == flag = Right xs
    | otherwise = Left $ "Expected '" ++ flag ++ "' but got '" ++ x ++ "'"

takeValue :: String -> [String] -> Either ParseError (String, [String])
takeValue flag [] = Left $ "Expected value after '" ++ flag ++ "' but reached end of arguments"
takeValue _ (x : xs) = Right (x, xs)

parseAction :: [String] -> Either ParseError (Action, [String])
parseAction [] = Left "Expected action value but reached end of arguments"
parseAction ("create-context" : rest) = Right (CreateContext, rest)
parseAction ("clone" : rest) = Right (Clone, rest)
parseAction ("serve" : rest) = Right (Serve, rest)
parseAction (x : _) = Left $ "Unknown action '" ++ x ++ "' (expected: create-context, clone, serve)"

parseServeArgs :: [String] -> Either ParseError ServeArgs
parseServeArgs = go (ServeArgs 3000 "repos")
  where
    go acc [] = Right acc
    go acc ("--port" : p : rest) = case reads p of
        [(n, "")] -> go (acc{servePort = n}) rest
        _ -> Left $ "Invalid port number: '" ++ p ++ "'"
    go acc ("--repos-dir" : d : rest) = go (acc{serveReposDir = d}) rest
    go _ ("--port" : []) = Left "'--port' requires a number"
    go _ ("--repos-dir" : []) = Left "'--repos-dir' requires a path"
    go _ (x : _) = Left $ "Unexpected argument '" ++ x ++ "'"

parseFilterRules :: [String] -> Either ParseError [FilterRule String]
parseFilterRules [] = Right []
parseFilterRules ("--include" : glob : rest) = (Include glob :) <$> parseFilterRules rest
parseFilterRules ("--exclude" : glob : rest) = (Exclude glob :) <$> parseFilterRules rest
parseFilterRules ("--include" : _) = Left "'--include' requires a glob pattern"
parseFilterRules ("--exclude" : _) = Left "'--exclude' requires a glob pattern"
parseFilterRules (x : _) = Left $ "Unexpected argument '" ++ x ++ "'"

usage :: String
usage =
    unlines
        [ "Usage:"
        , "  contextlm --action create-context"
        , "            --dir <directory>"
        , "            [--include <glob> | --exclude <glob>] ..."
        , ""
        , "  contextlm --action clone"
        , "            --url <url>"
        , "            --dir <directory>"
        , ""
        , "  contextlm --action serve"
        , "            [--port <port>]          (default: 3000)"
        , "            [--repos-dir <directory>] (default: repos)"
        , ""
        , "Arguments must appear in the order shown above."
        ]
