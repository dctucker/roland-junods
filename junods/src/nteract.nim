import std/terminal
import strutils

import cache
import memorymap

type
  State = ref object
  Nteract* = ref object
    prompt: string
    cmdline: string
    selected: int
    pos: int
    path: seq[string]
    coords: seq[int]
    map: Mem
    areas: seq[MemArea]

proc newNteract*(): Nteract =
  Nteract(
    prompt: "0x00000000> ",
    cmdline: "",
    pos: 0,
    selected: 0,
    path: @["", "setup"],
    map: juno_map,
    areas: @[juno_map.area],
    coords: @[0],
  )

proc draw(nt: Nteract) =
  stdout.write("\r\27[2K")
  stdout.write("\27[34;1m")
  stdout.write(nt.prompt)
  stdout.write("\27[0m")

  #stdout.write "\27[?25l\27[0K"
  stdout.write nt.cmdline

  let remlen = nt.cmdline.len - nt.pos
  #for c in [nt.pos .. nt.cmdline.len - 1]:
  #  stdout.write(nt.cmdline[c])
  if remlen > 0:
    stdout.write("\27[" & $remlen & "D")
  #stdout.write "\27[?25h"

proc clear(nt: Nteract) =
  nt.pos = 0
  nt.cmdline = ""
  nt.draw()
  stdout.flushFile()

proc get_kind(nt: Nteract): Kind =
  return nt.areas[^1][nt.selected].kind

proc get_offset(nt: Nteract): JAddr =
  var area = nt.areas[0][nt.coords[0]]
  for i in nt.coords[1..^1]:
    if area.offset != NOFF:
      result += area.offset
    if area.area.len() > 0:
      area = area.area[i]
  if area.offset != NOFF:
    result += area.offset

proc set_cmdline(nt: Nteract) =
  discard nt.coords.pop()
  discard nt.path.pop()
  let area = nt.areas[^1][nt.selected]
  nt.path.add( area.name )
  nt.coords.add( nt.selected )
  nt.cmdline = nt.path[1..^1].join(".")
  #nt.pos = nt.cmdline.len() - nt.path[^1].len()
  #echo nt.coords
  nt.prompt = nt.get_offset().format() & "> "

  case area.kind
  of TNone:
    nt.pos = nt.cmdline.len()
    nt.cmdline &= "."
  of TEnum:
    let value = cache_get(nt.get_offset(), nt.get_kind())[0]
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $area.kind & "(" & area.values[value] & ")"
  of TName, TName16:
    let value = cache_get(nt.get_offset(), nt.get_kind())
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $area.kind & "("
    for c in value:
      nt.cmdline &= c.char
    nt.cmdline &= ")"
  else:
    let value = cache_get(nt.get_offset(), nt.get_kind())
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $area.kind & "(" & value.join(",") & ")"

proc bs(nt: Nteract) =
  discard

proc up(nt: Nteract) =
  if nt.selected - 1 >= 0:
    nt.selected -= 1
    nt.set_cmdline()
    nt.draw()

proc down(nt: Nteract) =
  if nt.selected + 1 < nt.areas[^1].len:
    nt.selected += 1
    nt.set_cmdline()
    nt.draw()

proc left(nt: Nteract) =
  if nt.coords.len() <= 1:
    return
  discard nt.coords.pop()
  discard nt.areas.pop()
  discard nt.path.pop()
  nt.selected = nt.coords[^1]
  nt.set_cmdline()
  nt.draw()
  #echo $nt.coords

proc right(nt: Nteract) =
  if nt.areas[^1][nt.selected].area.len() == 0:
    return
  nt.coords.add(nt.selected)
  nt.path.add( nt.areas[^1][nt.selected].name )
  nt.areas.add( nt.areas[^1][nt.selected].area )
  nt.selected = 0
  nt.set_cmdline()
  nt.draw()
  #echo $nt.coords


#proc insert(nt: Nteract, k: string) =
#  nt.cmdline.insert($k, nt.pos)
#  nt.pos += 1
#  stdout.write(k)
#  if nt.pos < nt.cmdline.len:
#    nt.draw()

#proc bs(nt: Nteract) =
#  if nt.pos == 0 or nt.cmdline.len == 0:
#    return
#  cursorBackward()
#  stdout.write(" ")
#  cursorBackward()
#  if nt.pos == nt.cmdline.len:
#    nt.cmdline = nt.cmdline[0 .. nt.pos - 2]
#    nt.pos -= 1
#  else:
#    nt.cmdline = nt.cmdline[0 .. nt.pos - 2] & nt.cmdline[ nt.pos .. ^1 ]
#    nt.pos -= 1
#    nt.draw()

proc getUserInput*(nt: Nteract): string =
  nt.set_cmdline()
  nt.draw()
  var first = true
  while true:
    let k = getch()
    case k
    of '\3':
      echo "^C"
      quit 127
    of 'q', 'Q', '\4':
      echo ""
      quit 0
    of '\7', '\127':
      if first:
        nt.clear()
      else:
        nt.bs()
    of '\10', '\13':
      echo ""
      return nt.cmdline
    of '\27':
      case getch()
      of '[':
        case getch()
        of 'A': nt.up()
        of 'B': nt.down()
        of 'C': nt.right()
        of 'D': nt.left()
        #of '3':
        #  case getch()
        #  of '~': nt.fwdel()
        #  else: discard
        else: discard
      else: discard
    else:
      discard
      #nt.insert($k)
    first = false

