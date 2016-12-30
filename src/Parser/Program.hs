{-# LANGUAGE OverloadedStrings #-}

module Parser.Program where

import Control.Applicative
import Data.Attoparsec.Text
import qualified Data.Text as Text


-- my module
import AST
import Parser.Base
import Parser.Expr

programParser :: Text.Text -> Either String Stmt
programParser = parseOnly stmtParser

stmtParser :: Parser Stmt
stmtParser =
  stmtListParser <|>
  varSetParser <|>
  skipParser <|>
  ifParser <|>
  whileParser

stmtListParser :: Parser Stmt
stmtListParser = do
  lexeme $ char '('
  lexeme $ string "begin"
  stmtList <- many1 stmtParser
  lexeme $ char ')'
  return $ StmtList stmtList

varSetParser :: Parser Stmt
varSetParser = do
  lexeme $ char '('
  lexeme $ string "set!"
  v <- varParser
  e <- exprParser
  lexeme $ char ')'
  return $ VarSet v e

skipParser :: Parser Stmt
skipParser = do
  lexeme $ string "skip"
  return $ Skip

ifParser :: Parser Stmt
ifParser = do
  lexeme $ string "("
  lexeme $ string "if"
  expr <- exprParser
  s1 <- stmtParser
  s2 <- stmtParser
  lexeme $ string ")"
  return $ If expr s1 s2

whileParser :: Parser Stmt
whileParser = do
  lexeme $ string "("
  lexeme $ string "while"
  expr <- exprParser
  s <- stmtParser
  lexeme $ string ")"
  return $ While expr s
