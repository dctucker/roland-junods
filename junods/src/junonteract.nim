from strutils import join

import cache
import memorymap
import nteract
import values

type
  JunoNteract* = ref object of Nteract
    map: Mem
    areas: seq[MemArea]

proc newJunoNteract*(): JunoNteract =
  JunoNteract(
    prompt: "0x00000000> ",
    cmdline: "",
    pathsep: ".",
    pos: 0,
    selected: 0,
    path: @["", "setup"],
    map: juno_map,
    areas: @[juno_map.area],
    coords: @[0],
  )

proc get_kind(nt: JunoNteract): Kind =
  return nt.areas[^1][nt.selected].kind

proc get_offset(nt: JunoNteract): JAddr =
  var mem = nt.areas[0][nt.coords[0]]
  for i in nt.coords[1..^1]:
    if mem.offset != NOFF:
      result += mem.offset
    if mem.area.len() > 0:
      mem = mem.area[i]
  if mem.offset != NOFF:
    result += mem.offset

method set_cmdline(nt: JunoNteract) =
  let mem = nt.areas[^1][nt.selected]
  nt.Nteract.update_selected( mem.name )
  nt.cmdline = nt.path[1..^1].join(nt.pathsep)
  #nt.pos = nt.cmdline.len() - nt.path[^1].len()
  #echo nt.coords
  nt.prompt = $nt.get_offset() & "> "

  case mem.kind
  of TNone:
    nt.pos = nt.cmdline.len()
    nt.cmdline &= "."
  of TEnum:
    let value = cache_get(nt.get_offset(), nt.get_kind())[0]
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $mem.kind & "(" & $mem.values[value] & ")"
  of TName, TName16:
    let value = cache_get(nt.get_offset(), nt.get_kind())
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $mem.kind & "("
    for c in value:
      if c >= 32 and c <= 127:
        nt.cmdline &= c.char
    nt.cmdline &= ")"
  else:
    let value = cache_get(nt.get_offset(), nt.get_kind())
    nt.pos = nt.cmdline.len()
    nt.cmdline &= " = " & $mem.kind & "(" & $mem.value(value) & ")"

method current_len(nt: JunoNteract): int =
  nt.areas[^1].len()

method next_len(nt: JunoNteract): int =
  nt.areas[^1][nt.selected].area.len()

method pop_path(nt: JunoNteract) =
  discard nt.coords.pop()
  discard nt.areas.pop()
  discard nt.path.pop()

method push_path(nt: JunoNteract) =
  nt.coords.add(nt.selected)
  nt.path.add( nt.areas[^1][nt.selected].name )
  nt.areas.add( nt.areas[^1][nt.selected].area )

