import std/os
import strutils

import nteract

type
  Kind = enum
    KNone,
    KDir,
    KFile

type
  Entry* = object
    name: string
    kind: Kind
    can_exec: bool

  DirNteract* = ref object of Nteract
    list*: seq[Entry]
    lists: seq[seq[Entry]]

proc set_dir*(nt: DirNteract, pathstr: string)
proc newDirNteract*(): DirNteract =
  result = DirNteract(
    prompt: "",
    cmdline: "",
    pathsep: "" & DirSep,
    coords: @[0],
  )
  result.set_dir(getCurrentDir())

proc get_selected(nt: DirNteract): Entry =
  if nt.selected >= nt.list.len():
    Entry()
  else:
    nt.list[nt.selected]

proc set_dir*(nt: DirNteract, pathstr: string) =
  nt.path = pathstr.split(DirSep)
  nt.coords = @[]
  nt.lists = @[]
  nt.list = @[]

  var i = 0
  var search = nt.path[1]
  for p in getCurrentDir().parentDirs(fromRoot=true):
    nt.list = @[]
    var j = 0
    for dir in walkDirs(p & nt.pathsep & "*"):
      let name = dir.lastPathPart()
      nt.list.add(Entry(name: name, kind: KDir))
      if name == search:
        nt.coords.add(j)
      j += 1
    for file in walkFiles(p & nt.pathsep & "*"):
      let name = file.lastPathPart()
      nt.list.add(Entry(name: name, kind: KFile))
    nt.lists.add(nt.list)
    i += 1
    if i < nt.path.len() - 1:
      search = nt.path[i+1]
  nt.coords.add(0)
  let sel = if nt.list.len() > 0:
    nt.get_selected().name
  else:
    ""
  nt.path.add(sel)

proc load_list(nt: DirNteract) =
  let cd = nt.path.join(nt.pathsep)
  #echo "\ncd " & cd
  setCurrentDir(cd)
  nt.list = @[]
  for dir in walkDirs("*"):
    nt.list.add(Entry(name: dir, kind: KDir))
  for file in walkFiles("*"):
    nt.list.add(Entry(name: file, kind: KFile))
  #echo nt.list

method set_cmdline*(nt: DirNteract) =
  #echo nt.path
  #echo nt.coords
  #echo nt.lists
  #echo nt.list
  #echo nt.selected
  if nt.list.len() > 0:
    let sel = nt.get_selected().name
    nt.update_selected(sel)
  else:
    nt.update_selected("")
  nt.cmdline = nt.path.join(nt.pathsep) #& nt.pathsep & sel
  nt.pos = nt.cmdline.len()
  if nt.get_selected().kind == KDir:
    nt.cmdline &= "/"

method current_len(nt: DirNteract): int =
  nt.list.len()

method next_len(nt: DirNteract): int =
  if nt.get_selected().kind == KDir: 1
  else: 0

method push_path(nt: DirNteract) =
  nt.selected = 0
  nt.load_list()
  nt.coords.add(nt.selected)
  if nt.list.len() > 0:
    nt.path.add(nt.get_selected().name)
  else:
    nt.path.add("")
  nt.lists.add(nt.list)

method pop_path(nt: DirNteract) =
  if nt.lists.len() > 1:
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

