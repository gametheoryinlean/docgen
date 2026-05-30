/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import Lean

namespace DocGen4

open Lean Name

def getNLevels (name : Name) (levels: Nat) : Name :=
  let components := name.componentsRev
  (components.drop (components.length - levels)).reverse.foldl (· ++ ·) Name.anonymous

inductive Hierarchy where
| node (name : Name) (isFile : Bool) (children : RBNode Name (fun _ => Hierarchy)) : Hierarchy

instance : Inhabited Hierarchy := ⟨Hierarchy.node Name.anonymous false RBNode.leaf⟩

abbrev HierarchyMap := RBNode Name (fun _ => Hierarchy)

-- Everything in this namespace is adapted from stdlib's RBNode
namespace HierarchyMap

def toList : HierarchyMap → List (Name × Hierarchy)
| t => t.revFold (fun ps k v => (k, v)::ps) []

def toArray : HierarchyMap → Array (Name × Hierarchy)
| t => t.fold (fun ps k v => ps ++ #[(k, v)] ) #[]

def hForIn [Monad m] (t : HierarchyMap) (init : σ) (f : (Name × Hierarchy) → σ → m (ForInStep σ)) : m σ :=
  t.forIn init (fun a b acc => f (a, b) acc)

instance [Monad m] : ForIn m HierarchyMap (Name × Hierarchy) where
  forIn := HierarchyMap.hForIn

end HierarchyMap

namespace Hierarchy

def empty (n : Name) (isFile : Bool) : Hierarchy :=
  node n isFile RBNode.leaf

def getName : Hierarchy → Name
| node n _ _ => n

def getChildren : Hierarchy → HierarchyMap
| node _ _ c => c

def isFile : Hierarchy → Bool
| node _ f _ => f

partial def insert! (h : Hierarchy) (n : Name) : Hierarchy := Id.run do
  let hn := h.getName
  let mut cs := h.getChildren

  if getNumParts hn + 1 == getNumParts n then
    match cs.find Name.cmp n with
    | none =>
      node hn h.isFile (cs.insert Name.cmp n <| empty n true)
    | some (node _ true _) => h
    | some (node _ false ccs) =>
        cs := cs.erase Name.cmp n
        node hn h.isFile (cs.insert Name.cmp n <| node n true ccs)
  else
    let leveledName := getNLevels n (getNumParts hn + 1)
    match cs.find Name.cmp leveledName with
    | some nextLevel =>
      cs := cs.erase Name.cmp leveledName
      -- BUG?
      node hn h.isFile <| cs.insert Name.cmp leveledName (nextLevel.insert! n)
    | none =>
      let child := (insert! (empty leveledName false) n)
      node hn h.isFile <| cs.insert Name.cmp leveledName child

partial def fromArray (names : Array Name) : Hierarchy :=
  names.foldl insert! (empty anonymous false)

/--
Returns `true` if `n` was inserted into `h` as a file (i.e. was one of the
names passed to `fromArray` / `insert!`). Intermediate "container" nodes that
were synthesized to host children but never inserted as files themselves
return `false`.

Used by `moduleNameToLink` to decide local-vs-external linking: a module
present here goes through the relative URL path; anything else falls back to
the external documentation site.
-/
partial def contains (h : Hierarchy) (n : Name) : Bool :=
  let hn := h.getName
  let cs := h.getChildren
  let hParts := getNumParts hn
  let nParts := getNumParts n
  if hParts + 1 == nParts then
    match cs.find Name.cmp n with
    | none => false
    | some child => child.isFile
  else if hParts >= nParts then
    -- We've descended past the target's depth; no match possible.
    false
  else
    let leveledName := getNLevels n (hParts + 1)
    match cs.find Name.cmp leveledName with
    | none => false
    | some nextLevel => nextLevel.contains n

end Hierarchy
end DocGen4
