import std/os
import strutils

import nteract

type
  DirNteract* = ref object of Nteract
    list*: seq[string]
    lists: seq[seq[string]]

proc newDirNteract*(): DirNteract =
  let path = getCurrentDir().split(DirSep)
  result = DirNteract(
    prompt: "",
    cmdline: "",
    pathsep: "" & DirSep,
    path: path,
    coords: @[0],
  )

  var i = 0
  var search = result.path[1]
  for p in getCurrentDir().parentDirs(fromRoot=true):
    #echo "path: " & p
    #echo "searching for " & search
    result.list = @[]
    var j = 0
    for dir in walkDirs(p & result.pathsep & "*"):
      let name = dir.lastPathPart()
      #echo name
      result.list.add(name)
      if name == search:
        result.coords.add(j)
      j += 1
    result.lists.add(result.list)
    i += 1
    if i < result.path.len() - 1:
      search = result.path[i+1]
  result.coords.add(0)
  let sel = if result.list.len() > 0:
    result.list[result.selected]
  else:
    ""
  result.path.add(sel)

proc load_list(nt: DirNteract) =
  let cd = nt.path.join(nt.pathsep)
  #echo "\ncd " & cd
  setCurrentDir(cd)
  nt.list = @[]
  for dir in walkDirs("*"):
    nt.list.add(dir)
  #echo nt.list

method set_cmdline*(nt: DirNteract) =
  #echo nt.path
  #echo nt.coords
  #echo nt.lists
  #echo nt.list
  #echo nt.selected
  if nt.list.len() > 0:
    let sel = nt.list[nt.selected]
    nt.update_selected(sel)
  else:
    nt.update_selected("")
  nt.cmdline = nt.path.join(nt.pathsep) #& nt.pathsep & sel
  nt.pos = nt.cmdline.len()

method current_len(nt: DirNteract): int =
  nt.list.len()

method next_len(nt: DirNteract): int =
  1

method push_path(nt: DirNteract) =
  nt.selected = 0
  nt.load_list()
  nt.coords.add(nt.selected)
  if nt.list.len() > 0:
    nt.path.add(nt.list[nt.selected])
  else:
    nt.path.add("")
  nt.lists.add(nt.list)

method pop_path(nt: DirNteract) =
  discard nt.coords.pop()
  discard nt.path.pop()
  discard nt.lists.pop()
  nt.list = nt.lists[^1]
  nt.selected = nt.coords[^1]

when isMainModule:
  #setCurrentDir("/")
  let nt = newDirNteract()
  let input = nt.getUserInput()
  echo input

