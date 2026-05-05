module Types where

data Action = AddContext deriving (Show, Eq)

data GitSource = GitSource
  { gsUrl :: String
  } deriving (Show, Eq)

data ContextSource
  = CSGitSource GitSource
  deriving (Show, Eq)

data FilterRule = Include String | Exclude String deriving (Show, Eq)

data ContextFilter
  = CFFileSystemFilter [FilterRule]
  deriving (Show, Eq)

data AddContextArgs = AddContextArgs
  { outFile       :: FilePath
  , title         :: String
  , contextSource :: ContextSource
  , contextFilter :: ContextFilter
  } deriving (Show, Eq)

data Command = AddContextCmd AddContextArgs deriving (Show, Eq)
