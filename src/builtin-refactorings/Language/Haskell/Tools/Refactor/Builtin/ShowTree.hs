
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE MonoLocalBinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE TupleSections #-}
{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Language.Haskell.Tools.Refactor.Builtin.ShowTree where

import Language.Haskell.Tools.Refactor as Refactor hiding (LambdaCase)
import Language.Haskell.Tools.Refactor.Utils.Extensions
import Language.Haskell.Tools.Rewrite.Match.Binds
-- import Language.Haskell.Tools.AST.Representation.Binds as AST

import GHC
import Module as GHC
import InstEnv as GHC
import Unify as GHC
import Type as GHC
import Name as GHC
import Var as GHC
import UniqSupply as GHC
import Unique as GHC
import TysWiredIn as GHC
import TysPrim as GHC
import PrelNames as GHC
import ConLike as GHC
import PatSyn as GHC
import BasicTypes as GHC

import Control.Reference
import Data.Char (isAlphaNum)
import Data.Function (on)
import Data.Maybe (mapMaybe)
import Data.List
import qualified Data.Map.Strict as SMap (empty, toList)

import Debug.Trace (trace, traceShowId)

import Outputable
import Language.Haskell.Tools.PrettyPrint

import Language.Haskell.Tools.BackendGHC.Exprs (trfExpr)
import Language.Haskell.Tools.BackendGHC.GHCUtils (occName, fromSrcText)
import Language.Haskell.Tools.BackendGHC.Names
import Language.Haskell.Tools.BackendGHC.Patterns (trfPattern)
import Language.Haskell.Tools.BackendGHC.Types (trfType)

import Language.Haskell.Tools.AST (Ann, AnnMaybeG, AnnListG, Dom, RangeStage)
import qualified Language.Haskell.Tools.AST as AST

import Control.Monad.IO.Class

import Language.Haskell.Tools.Refactor
import Language.Haskell.Tools.Debug.RangeDebug
import Language.Haskell.Tools.Debug.RangeDebugInstances
import Control.Monad.IO.Class
import Language.Haskell.Tools.Refactor.ChopperFile 


-- NOTE: When working on the entire AST, we should build a monad,
--       that will will avoid unnecessary checks.
--       For example if it already found a record wildcard, it won't check again

--       Pretty easy now. Chcek wheter it is already in the ExtMap.

showAstTree :: RefactoringChoice
showAstTree = ModuleRefactoring "writeBack" (localRefactoring writeBack)


writeBack :: LocalRefactoring
writeBack ast =
        do
            moduleAST <- liftIO $ moduleParser "/home/chaitanya/Desktop/work/euler-api-txns/euler-x/src-generated/ConfigFramework/Storage/ConfigMeta.hs" "ConfigFramework.Storage.ConfigMeta"
            !newAST <- liftGhc $ (!~) (biplateRef) (logicFn) (moduleAST)
            liftIO $ writeFile "Shims.hs" (prettyPrint newAST)
            return ast

check :: Decl -> Bool 
check (InstanceDecl (InstanceRule _ _ (AppInstanceHead fn _)) _) =
                                                let (x :: [String]) = fn ^? biplateRef
                                                in not $ any (\x -> x == "HasField") x    
check _ = True

-- UApp {_exprFun = UApp {_exprFun = UExplTypeApp {_exprInner = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [UNamePart {_simpleNameStr = "GHC"},UNamePart {_simpleNameStr = "Records"},UNamePart {_simpleNameStr = "Extra"}], _unqualifiedName = UNamePart {_simpleNameStr = "setField"}}}},
--                                                               _exprType = UTyPromoted {_tpPromoted = UPromotedString {_promotedStringValue = "name"}}}, 
--                   _exprArg = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "pm"}}}}}, 
--       _exprArg = ULit {_exprLit = UStringLit {_stringLitValue = "MASTER"}}}

-- UInfixApp {_exprLhs = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "x"}}}},
--            _exprOperator = UNormalOp {_operatorName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "^."}}},
--            _exprRhs = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [UNamePart {_simpleNameStr = "L"}], _unqualifiedName = UNamePart {_simpleNameStr = "_merchantAccountId"}}}}}

-- ULet {_exprFunBind = [ULocalValBind {_localVal = USimpleBind {_valBindPat = UVarPat {_patternName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "dingding"}}}},
--                                                               _valBindRhs = UUnguardedRhs {_rhsExpr = UParen {_exprInner = UApp {_exprFun = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "encodeDecodeTransform"}}}},
--                                                                                                                                  _exprArg = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "scope"}}}}}}},
--                                                               _valBindLocals = Nothing}}],
--       _exprInner = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "dingding"}}}}}

logicFn :: Expr -> Ghc Expr 
-- logicFn expr@(App (Var arg) ex@x) = do
--   let fnName  = trace (showName arg) showName arg 
--       pat = mkVarPat $ mkName "a"
--   let app = mkApp (mkVar $ mkName "encodeDecodeTransform") ex
--       updatedRhs = mkUnguardedRhs app
--       lclbnd = mkLocalValBind $ mkSimpleBind pat updatedRhs Nothing 
--       var = mkVar $ mkName "a"
--       letExpr = mkLet [lclbnd] var
--   if fnName == "encodeDecodeTransform"
--     then return letExpr
--     else return expr
logicFn expr@(App (App (Var arg) (Var arg1)) ex@x) = do
  let fnName  = trace (showName arg) showName arg1 
      pat = mkVarPat $ mkName "a"
      updatedRhs = mkUnguardedRhs expr
      lclbnd = mkLocalValBind $ mkSimpleBind pat updatedRhs Nothing 
      var = mkVar $ mkName "a"
      letExpr = mkLet [lclbnd] var
  if fnName == "encodeDecodeTransform"
    then return letExpr
    else return expr

logicFn x = trace ("Extra setFiled " ++ show x) $ return x
-- logicFn expr@(Let (LocalBinds [(SimpleBind _ (UnguardedRhs (Paren (App (Var arg1) (Var arg2)))) _ )]) (Var arg)) = do
--     let !y1 = trace ("Extra getFiled 1" ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg)) $ showName arg
--     let !y2 = trace ("Extra getFiled 1" ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg1)) $ showName arg
--     return expr

-- ULet {_exprFunBind = [ULocalValBind {_localVal = USimpleBind {_valBindPat = UVarPat {_patternName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "dongg"}}}},
--                                                               _valBindRhs = UUnguardedRhs {_rhsExpr = UApp {_exprFun = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "encodeDecodeTransform"}}}},
--                                                                                                             _exprArg = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "keyUuid"}}}}}},
--                                                               _valBindLocals = Nothing}}], _exprInner = UVar {_exprName = UNormalName {_simpleName = UQualifiedName {_qualifiers = [], _unqualifiedName = UNamePart {_simpleNameStr = "dongg"}}}}}

-- logicFn expr@(Let (AST.AnnListG annot [LocalValBind (SimpleBind _ (UnguardedRhs ((App (Var arg1) (Var arg2)))) _ )]) (Var arg)) = do
--     let !y1 = trace ("Extra LocalValBind 1 " ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg)) $ showName arg
--     let !y2 = trace ("Extra LocalValBind 1 " ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg2)) $ showName arg
--     return $ mkVar $ mkName $ "Just " ++ showName arg2
-- logicFn expr@(Let (AST.AnnListG annot [LocalValBind (SimpleBind _ (UnguardedRhs (Paren (App (Var arg1) (Var arg2)))) _ )]) (Var arg)) = do
--     -- let y = x ^. simpleBind
--     let !y1 = trace ("Extra LocalValBind 1 " ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg)) $ showName arg
--     let !y2 = trace ("Extra LocalValBind 1 " ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg2)) $ showName arg
--     return expr
-- logicFn expr@(InfixApp (Var arg) op (Var arg1)) = do
--     let !y1 = trace ("Extra getFiled 1" ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg)) $ showName arg
--     let !y2 = trace ("Extra getFiled 1" ++ (showSDocUnsafe $ ppr $ idType $ semanticsId arg1)) $ showName arg
--     return expr
logicFn x = return x