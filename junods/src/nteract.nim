import std/terminal

type
  State = ref object
  Nteract* = ref object of RootObj
    prompt*: string
    cmdline*: string
    pathsep*: string
    selected*: int
    pos*: int
    path*: seq[string]
    coords*: seq[int]

method draw(nt: Nteract) {.base.} =
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

method clear(nt: Nteract) {.base.} =
  nt.pos = 0
  nt.cmdline = ""
  nt.draw()
  stdout.flushFile()

method update_selected*(nt: Nteract, sel: string) {.base.} =
  #echo nt.coords
  discard nt.coords.pop()
  discard nt.path.pop()
  nt.path.add(sel)
  nt.coords.add( nt.selected )

method set_cmdline(nt: Nteract) {.base.} = discard
method current_len(nt: Nteract): int {.base.} = 0
method next_len(nt: Nteract): int {.base.} = 0
method pop_path(nt: Nteract) {.base.} = discard
method push_path(nt: Nteract) {.base.} = discard

method bs(nt: Nteract) {.base.} = discard
method up(nt: Nteract) {.base.} =
  if nt.selected - 1 >= 0:
    nt.selected -= 1
    nt.set_cmdline()
    nt.draw()

method down(nt: Nteract) {.base.} =
  if nt.selected + 1 < nt.current_len():
    nt.selected += 1
    nt.set_cmdline()
    nt.draw()

method left(nt: Nteract) {.base.} =
  if nt.coords.len() <= 1:
    return
  nt.pop_path()
  nt.selected = nt.coords[^1]
  nt.set_cmdline()
  nt.draw()
  #echo $nt.coords

method right(nt: Nteract) {.base.} =
  if nt.next_len() == 0:
    return
  nt.push_path()
  nt.selected = 0
  nt.set_cmdline()
  nt.draw()
  #echo $nt.coords


#method insert(nt: Nteract, k: string) {.base.} =
#  nt.cmdline.insert($k, nt.pos)
#  nt.pos += 1
#  stdout.write(k)
#  if nt.pos < nt.cmdline.len:
#    nt.draw()

#method bs(nt: Nteract) {.base.} =
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

method getUserInput*(nt: Nteract): string {.base.} =
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

