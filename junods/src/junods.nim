import nteract
import junonteract
import cache

import memorymap
from strutils import join, indent, toHex

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
  for m in mem.area:
    visit m, level + 1

#when isMainModule:
#  let top_area* {.importc.}: AdapterArray
#  #let mem = top_area[0]
#  for mem in top_area:
#    echo mem.offset, " ", mem.name
#  #echo mem.area.repr

when isMainModule:
  visit juno_map

#when isMainModule:
#  initCache()
#  #visit juno_map
#  let nt = newJunoNteract()
#  let input = nt.getUserInput()
#  echo input
#  ##for area in nt.areas[^1]:
#  ##  echo area.name
#  #traverse(juno_map, 0.JAddr, @[])

