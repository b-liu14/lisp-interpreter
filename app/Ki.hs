{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Main (main) where

import Control.Monad
import Options.Applicative
import qualified Data.Attoparsec.Text as AttoText
import qualified Data.Text as Text
import System.IO
import System.Exit
import qualified Data.Map as Map
import qualified Text.PrettyPrint as PP
import qualified Text.PrettyPrint.GenericPretty as GP
import System.Console.Haskeline

-- my module
import Eval.Prog
import Eval.Expr
import Parser.Prog
import Parser.Func
import Parser.Stmt
import Parser.Expr
import AST
import Memory
import FileIO

data ArgOptions = ArgOptions
  { instructions :: String
  , output :: String
  , tree :: String
  , replMode :: Bool}

argParser :: Parser ArgOptions
argParser = ArgOptions
     <$> strOption
         ( short 'i'
        <> long "instructions"
        <> metavar "INPUT_PATH"
        <> value ""
        <> help "path of instructions to execute." )
     <*> strOption
         ( short 'o'
        <> long "output"
        <> metavar "OUTPUT_PATH"
        <> value ""
        <> help "path to output" )
     <*> strOption
         ( short 't'
        <> long "tree"
        <> metavar "INPUT_PATH"
        <> value ""
        <> help "path of program to parse")
     <*> switch
         ( short 'r'
         <> long "repl"
         <> help "REPL mode")

data History = FunctionDefine Func
  | Statement Stmt
  | Expression Expr
  | NoHistory
  deriving (Show, Read, Eq, GP.Out, GP.Generic)

-- execute expression
execute_expr :: History -> Mem -> Text.Text -> InputT IO()
execute_expr history mem expr =
  let expr_or_str = AttoText.parseOnly exprParser expr in do
  case expr_or_str of
    -- syntax error
    (Left str) -> do -- error handy
      outputStrLn $ error_msg expr str
      repl history mem
    -- syntax right, eval the expression, then run again
    (Right expr) -> do
      let result = eval_expr expr mem in do
        outputStrLn $ show result
        repl (Expression expr) mem

-- execute statement
execute_stmt :: History -> Mem -> Text.Text -> InputT IO()
execute_stmt history mem stmt =
  let stmt_or_str = AttoText.parseOnly stmtParser stmt in do
  case stmt_or_str of
    -- syntax error
    (Left str) -> do
      outputStrLn $ error_msg stmt str
      repl history mem
    (Right (Return expr)) -> do
      outputStrLn $ "REPL mode don't support return statement."
      repl history mem
    -- syntax right, eval the stmt, update stmt and memory, then run again
    (Right stmt) -> do
      let new_mem = eval_stmt stmt mem in do
        outputStrLn $ mempp new_mem
        repl (Statement stmt) new_mem

-- execute function
execute_func :: History -> Mem -> Text.Text -> InputT IO()
execute_func history mem func =
  let func_or_str = AttoText.parseOnly funcParser func in do
  case func_or_str of
    -- syntax error
    (Left str) -> do -- error handy
      outputStrLn $ error_msg func str
      repl history mem
    -- syntax right, eval the stmt, update stmt and memory, then run again
    (Right func) -> do
      let new_mem = insertFunc func mem in do
        outputStrLn $ mempp new_mem
        repl (FunctionDefine func) new_mem

-- output the parse result of last history
show_tree :: History -> Mem -> InputT IO()
show_tree NoHistory mem = do
  outputStrLn "No history instruction!"
  repl NoHistory mem
show_tree history mem = do
  outputStrLn $ PP.render $ GP.doc $ history
  repl history mem

repl_help_message :: String
repl_help_message = " \n" ++
  "Usage:\n" ++
  "  :h                      Show this help text \n" ++
  "  :i <stmt>               Execute Statement \n" ++
  "  :f <func>               Define Function \n" ++
  "  :e <expr>               execute Expression \n" ++
  "  :t                      Print Abstract Semantic Tree of Last Function/Statement/Expression \n" ++
  "  :q                      Quit \n" ++
  " "


repl :: History -> Mem -> InputT IO ()
repl history mem = do
  minput <- getInputLine "ki >>> "
  case minput of
    Nothing -> return ()
    Just input -> do
      case words input of
        [] -> repl history mem
        -- execute statement
        ":i":others -> execute_stmt history mem $ Text.pack $ unwords others
        -- tree
        ":t":others -> show_tree history mem
        -- quit
        ":q":others -> outputStrLn "Bye~"
        -- define function
        ":f":others -> execute_func history mem $ Text.pack $ unwords others
        -- execute expression
        ":e":others -> execute_expr history mem $ Text.pack $ unwords others
        -- help
        ":h":others -> do
          outputStrLn repl_help_message
          repl history mem
        -- clean all memory.
        ":c":others -> repl history Map.empty
        -- command syntax error
        otherwise -> do
          outputStrLn $ concat ["syntax error in:\n", input, ".\n", repl_help_message]
          repl history mem

interpret :: ArgOptions -> IO ()
-- repl
interpret (ArgOptions _ _ _ True) = do
  putStrLn "Enter REPL mode"
  runInputT defaultSettings $ repl NoHistory Map.empty

-- execute instruction
interpret (ArgOptions i o "" False) = do
  program <- readWholeFile i
  case programParser program of
    -- syntax error
    (Left str) -> putStrLn $ error_msg program str
    -- syntax right, eval the statement
    (Right stmt) -> writeToFile o $ mempp (eval stmt Map.empty)

-- tree
interpret (ArgOptions "" o t False) = do
  program <- readWholeFile t
  case programParser program of
    -- syntax error
    (Left str) -> putStrLn $ error_msg program str
    -- syntax right, output the parse tree.
    (Right stmt) -> writeToFile o $ PP.render $ GP.doc $ stmt
interpret _ = putStrLn "syntax error."

main :: IO ()
main = execParser opts >>= interpret
  where
    opts = info (helper <*> argParser )
      ( fullDesc
     <> progDesc ""
     <> header "一个使用haskell写的解释器" )
