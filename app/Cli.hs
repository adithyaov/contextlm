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
parseAction (x : _) = Left $ "Unknown action '" ++ x ++ "' (expected: create-context, clone)"

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
        , "            --out <file>"
        , "            --title <title>"
        , "            --dir <directory>"
        , "            [--include <glob> | --exclude <glob>] ..."
        , ""
        , "  contextlm --action clone"
        , "            --url <url>"
        , "            --dir <directory>"
        , ""
        , "Arguments must appear in the order shown above."
        ]
