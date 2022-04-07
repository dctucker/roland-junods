import nteract
import junonteract
import cache

import memorymap
import strutils

proc traverse(mem: Mem, offset: JAddr, path: seq[string]) =
  let level = path.len
  var a = offset
  var hidden = mem.kind == TNone or mem.offset == NOFF
  if mem.offset != NOFF:
    a += mem.offset
  if not hidden:
    stdout.write $a, " "

  var desc = (path & mem.name).join(".")
  if desc.len > 0:
    desc = desc[1..^1]

  if not hidden:
    stdout.write desc
    stdout.write "\n"
  for area in mem.area:
    traverse(area, a, path & mem.name)

proc visit(mem: Mem, level: int = 0) =
  echo indent($mem, level*4)
  for area in mem.area:
    visit area, level + 1

#when isMainModule:
#  visit juno_map

when isMainModule:
  initCache()
  #visit juno_map
  let nt = newJunoNteract()
  let input = nt.getUserInput()
  echo input
  ##for area in nt.areas[^1]:
  ##  echo area.name
  #traverse(juno_map, 0.JAddr, @[])

