import strutils

type
  Kind* = enum
    TNone,
    TBool,
    TNibble,
    TEnum,
    TByte,
    TNibblePair,
    TNibbleQuad,
    TName,
    TName16,
  JAddr* = int64
const NOFF*: JAddr = -1

type
  Mem* = ref object # tree structure for describing areas of device memory
    offset*: JAddr
    case kind*: Kind
    of TEnum:
      values*: seq[string]
    of TByte, TNibble, TNibblePair, TNibbleQuad:
      low*, high*: int
    else:
      discard
    name*:   string
    area*:  seq[Mem]
  MemArea* = seq[Mem]

proc normalize*(offset: JAddr): JAddr =
  if offset == NOFF:
    return offset
  let n3: JAddr = (offset and 0x7f000000)
  let n2: JAddr = (offset and 0x007f0000) or ((offset and 0x00800000) shl 1)
  let n1: JAddr = (offset and 0x00007f00) or ((offset and 0x00008000) shl 1)
  let n0: JAddr = (offset and 0x0000007f) or ((offset and 0x00000080) shl 1)
  return (n3 or n2 or n1 or n0) and 0x7f7f7f7f

proc format*(a: JAddr): string =
  return "0x" & a.toHex(8).toLower()

proc `+=`*(n1: var JAddr, n2: JAddr) =
  n1 = normalize(n1 + n2)

proc CM(offset: JAddr, name: string, kind: Kind = TNone, values: seq[string] = @[]): Mem =
  case kind
  of TEnum:
    Mem(offset: normalize(offset), name: name, kind: kind, values: values)
  else:
    Mem(offset: normalize(offset), name: name, kind: kind)

proc CM(offset: JAddr, name: string, kind: Kind = TNone, low, high: int): Mem =
  case kind
  of TByte, TNibble, TNibblePair, TNibbleQuad:
    Mem(offset: normalize(offset), name: name, kind: kind, low: low, high: high)
  else:
    Mem(offset: normalize(offset), name: name, kind: kind)


proc CMA(offset: JAddr, name: string, area: varargs[Mem]): Mem =
  Mem(offset: normalize(offset), name: name, area: @area)

proc CMAO(name: string, area: varargs[Mem]): Mem =
  CMA(NOFF, name, area)

proc repeat(thing: MemArea, n, span: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    result.add(CMA(JAddr(span * i), $(i + 1), thing))

proc repeat(thing: Mem, n, span: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    case thing.kind
    of TEnum:
      result.add( CM(JAddr(span * i), $(i + 1), thing.kind, thing.values) )
    of TByte, TNibble, TNibblePair, TNibbleQuad:
      result.add( CM(JAddr(span * i), $(i + 1), thing.kind, thing.low, thing.high) )
    else:
      result.add( CM(JAddr(span * i), $(i + 1), thing.kind) )

proc repeat(kind: Kind, n, span: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    result.add(CM(JAddr(span * i), $(i + 1), kind))

let scale_map = @[
  CM(0x00, "c" , TByte, 0, 127), # -64 .. +63
  CM(0x01, "c#", TByte, 0, 127), # -64 .. +63
  CM(0x02, "d" , TByte, 0, 127), # -64 .. +63
  CM(0x03, "d#", TByte, 0, 127), # -64 .. +63
  CM(0x04, "e" , TByte, 0, 127), # -64 .. +63
  CM(0x05, "f" , TByte, 0, 127), # -64 .. +63
  CM(0x06, "f#", TByte, 0, 127), # -64 .. +63
  CM(0x07, "g" , TByte, 0, 127), # -64 .. +63
  CM(0x08, "g#", TByte, 0, 127), # -64 .. +63
  CM(0x09, "a" , TByte, 0, 127), # -64 .. +63
  CM(0x0a, "a#", TByte, 0, 127), # -64 .. +63
  CM(0x0b, "b" , TByte, 0, 127), # -64 .. +63
]

proc generate_control_source_values(): seq[string] =
  result.add("OFF")
  for i in 1 .. 31:
    result.add("CC" & $i)
  for i in 33 .. 95:
    result.add("CC" & $i)
  result.add("BEND")
  result.add("AFT")

let control_source_values = generate_control_source_values()
let mfx_control_source_values = control_source_values & @["SYS1","SYS2","SYS3","SYS4"]
let matrix_control_source_values = mfx_control_source_values & @["VELOCITY","KEYFOLLOW","TEMPO","LFO1","LFO2","PIT-ENV","TVF-ENV","TVA-ENV"]
let controls = @[
  CM(0, "source", TEnum, mfx_control_source_values),
  CM(1, "sens"  , TByte, 1, 127), # -63 .. +63
]
let control = controls.repeat(4, 2) & @[
  CMA(8, "assign", Mem(kind: TByte, low: 0, high: 16).repeat(4,1))
]

let parameters_20 = Mem(kind: TNibbleQuad, low: 12768, high: 52768).repeat(20, 4)
let parameters_32 = Mem(kind: TNibbleQuad, low: 12768, high: 52768).repeat(32, 4)
let output_assign_values = @["A","---","---","---"]

let mfx = @[
  CM( 0x00, "type"       , TByte, 0, 80),
  CM( 0x01, "dry_send"   , TByte, 0, 127),
  CM( 0x02, "chorus_send", TByte, 0, 127),
  CM( 0x03, "reverb_send", TByte, 0, 127),
  CM( 0x04, "output_asssign", TEnum, output_assign_values),
  CMA(0x05, "control", control),
  CMA(0x11, "parameter", parameters_32),
]

let chorus = @[
  CM( 0x00, "type" , TByte, 0, 3),
  CM( 0x01, "level", TByte, 0, 127),
  CM( 0x02, "output_assign", TEnum, output_assign_values),
  CM( 0x03, "output_select", TEnum, @["MAIN","REV","MAIN+REV"]),
  CMA(0x04, "parameter", parameters_20),
]
let reverb = @[
  CM( 0x00, "type" , TEnum, 0, 5),
  CM( 0x01, "level", TByte, 0, 127),
  CM( 0x02, "output_assign", TEnum, output_assign_values),
  CMA(0x03, "parameter", parameters_20),
]

let midi_n = @[
  CMAO("rx",
    CM(0x00, "pc"              , TBool),
    CM(0x01, "bank"            , TBool),
    CM(0x02, "bend"            , TBool),
    CM(0x03, "key_pressure"    , TBool),
    CM(0x04, "channel_pressure", TBool),
    CM(0x05, "modulation"      , TBool),
    CM(0x06, "volume"          , TBool),
    CM(0x07, "pan"             , TBool),
    CM(0x08, "expression"      , TBool),
    CM(0x09, "hold_1"          , TBool),
  ),
  CM(0x0a, "phase_lock"        , TBool),
  CM(0x0b, "velocity_curve_type", TByte, 0, 4), # 0=OFF
]
let off_on_patch = @["OFF","ON","PATCH"]

let part_n = @[
  CM(0x00, "rx_channel", TNibble, 0, 15),
  CM(0x01, "rx_switch", TBool),
  #CM(0x02, "reserved_1"),
  CM(0x04, "patch_bank_msb", TByte, 0, 127),
  CM(0x05, "patch_bank_lsb", TByte, 0, 127),
  CM(0x06, "patch_pc"      , TByte, 0, 127),
  CM(0x07, "level", TByte, 0, 127),
  CM(0x08, "pan", TByte, 0, 127),
  CM(0x09, "coarse_tune", TByte, 16, 112),
  CM(0x0a, "fine_tune", TByte, 14, 114),
  CM(0x0b, "mono_poly", TEnum, @["MONO","POLY","PATCH"]),
  CM(0x0c, "legato", TEnum, off_on_patch),
  CM(0x0d, "bend_range", TByte, 0, 25), # 25=PATCH
  CM(0x0e, "portamento_switch", TEnum, off_on_patch),
  CM(0x0f, "portamento_time" , TNibblePair, 0, 128), # 128=PATCH
  CM(0x11, "cutoff_offset"   , TByte, 0, 127), # -64 .. +63
  CM(0x12, "resonance_offset", TByte, 0, 127), # -64 .. +63
  CM(0x13, "attack_offset"   , TByte, 0, 127), # -64 .. +63
  CM(0x14, "release_offset"  , TByte, 0, 127), # -64 .. +63
  CM(0x15, "octave_shift"    , TByte, 61, 67), #  -3 .. +3
  CM(0x16, "velocity_sens_offset", TByte, 1, 127), # -63 .. +63
  #CM(0x17, "reserved_2"),
  CM(0x1b, "mute", TBool),
  CM(0x1c, "dry_send"   , TByte, 0, 127),
  CM(0x1d, "chorus_send", TByte, 0, 127),
  CM(0x1e, "reverb_send", TByte, 0, 127),
  CM(0x1f, "output_assign", TEnum, @["MFX","A","---","---","---", $1, $2, "---","---","---","---","---","---","PART"]),
  CM(0x20, "output_mfx_select", TEnum, @["MFX1","MFX2","MFX3"]),
  CM(0x21, "decay_offset" , TByte, 0, 127), # -64 .. +63
  CM(0x22, "vibrato_rate" , TByte, 0, 127), # -64 .. +63
  CM(0x23, "vibrato_depth", TByte, 0, 127), # -64 .. +63
  CM(0x24, "vibrato_delay", TByte, 0, 127), # -64 .. +63
  CMA(0x25, "scale", scale_map),
]

let zone_n = @[
  CM(0x00, "octave_shift", TByte, 61, 67), #  -3 .. +3
  CM(0x01, "switch", TBool),
  #CM(0x02, "reserved_1"),
  CM(0x0c, "range_lower", TByte, 0, 127),
  CM(0x0d, "range_upper", TByte, 0, 127),
  #CM(0x0e, "reserved_2"),
  #CM(0x1a, "reserved_3"),
]

let matrix_control_dest_values = @[
  "OFF", "PCH", "CUT", "RES", "LEV", "PAN",
  "DRY", "CHO", "REV", "PIT-LFO1",
  "PIT-LFO2", "TVF-LFO1", "TVF-LFO2",
  "TVA-LFO1", "TVA-LFO2", "PAN-LFO1",
  "PAN-LFO2", "LFO1-RATE", "LFO2-RATE",
  "PIT-ATK", "PIT-DCY", "PIT-REL",
  "TVF-ATK", "TVF-DCY", "TVF-REL",
  "TVA-ATK", "TVA-DCY", "TVA-REL",
  "TMT", "FXM", "MFX1", "MFX2", "MFX3", "MFX4",
]
let matrix_control = @[
  CM(0, "source", TEnum, matrix_control_source_values),
  CM(1, "destination_1", TEnum, matrix_control_dest_values),
  CM(2, "sens_1", TByte, 1, 127), # -63 .. +63
  CM(3, "destination_2", TEnum, matrix_control_dest_values),
  CM(4, "sens_2", TByte, 1, 127), # -63 .. +63
  CM(5, "destination_3", TEnum, matrix_control_dest_values),
  CM(6, "sens_3", TByte, 1, 127), # -63 .. +63
  CM(7, "destination_4", TEnum, matrix_control_dest_values),
  CM(8, "sens_4", TByte, 1, 127), # -63 .. +63
]

let keyboard_ranges = @[
  CM(0, "range_lower", TByte, 0, 127),
  CM(1, "range_upper", TByte, 0, 127),
  CM(2, "fade_lower" , TByte, 0, 127),
  CM(3, "fade_upper" , TByte, 0, 127),
]
let velocity_ranges = @[
  CM(0, "range_lower", TByte, 1, 127),
  CM(1, "range_upper", TByte, 1, 127),
  CM(2, "fade_lower" , TByte, 0, 127),
  CM(3, "fade_upper" , TByte, 0, 127),
]
let tmt_n = @[
  CM(0, "tone_switch", TBool),
  CMA(1, "keyboard", keyboard_ranges),
  CMA(5, "velocity", velocity_ranges),
]
let booster_values = @["0","+6","+12","+18"]
let tmt = @[
  CMAO("1-2",
    CM(0x00, "structure_type", TByte, 0, 9),
    CM(0x01, "booster", TEnum, booster_values),
  ),
  CMAO("3-4",
    CM(0x02, "structure_type", TByte, 0, 9),
    CM(0x03, "booster", TEnum, booster_values),
  ),
  CM(0x04, "velocity_control", TEnum, @["OFF","ON","RANDOM","CYCLE"]),
  CMA(0x05, "1", tmt_n),
  CMA(0x0e, "2", tmt_n),
  CMA(0x17, "3", tmt_n),
  CMA(0x20, "4", tmt_n),
]

let tone_control_switches = @[
  CMAO("switch",
    Mem(kind: TEnum, values: @["OFF","ON","REVERSE"]).repeat(4, 1)
  ),
]
let random_pitch_depth_values = @[ $0, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $20, $30, $40, $50, $60, $70, $80, $90, $100, $200, $300, $400, $500, $600, $600, $700, $800, $900, $1000, $1100, $1200 ]
let tvf_filter_types = @["OFF","LPF","BPF","HPF","PKG","LPF2","LPF3"]

let patch_tone_n = @[
  CM( 0x0000, "level", TByte, 0, 127),
  CM( 0x0001, "coarse_tune", TByte, 16, 112), # -48 .. +48
  CM( 0x0002, "fine_tune"  , TByte, 14, 114), # -50 .. +50
  CM( 0x0003, "random_pitch_depth", TEnum, random_pitch_depth_values),
  CM( 0x0004, "pan", TByte, 0, 127),
  CM( 0x0005, "pan_keyfollow", TByte, 54, 74), # -100 .. +100
  CM( 0x0006, "random_pan_depth", TByte, 0, 63),
  CM( 0x0007, "alt_pan_depth", TByte, 1, 127),
  CM( 0x0008, "env_sustain", TEnum, @["NO-SUS","SUSTAIN"]),
  CM( 0x0009, "delay_mode", TEnum, @["NORMAL","HOLD","KEY-OFF-NORMAL","KEY-OFF-DECAY"]),
  CM( 0x000a, "delay_time", TNibblePair, 0, 149), # 0 - 127, MUSICAL-NOTES
  CM( 0x000c, "dry_send"       , TByte, 0, 127),
  CM( 0x000d, "chorus_send_mfx", TByte, 0, 127),
  CM( 0x000e, "reverb_send_mfx", TByte, 0, 127),
  CM( 0x000f, "chorus_send"    , TByte, 0, 127),
  CM( 0x0010, "reverb_send"    , TByte, 0, 127),
  CM( 0x0011, "output_assign", TEnum, @["MFX","A","---","---","---", $1, $2, "---","---","---","---","---","---"]),
  CMAO("rx",
    CM( 0x0012, "bend"      , TBool),
    CM( 0x0013, "expression", TBool),
    CM( 0x0014, "hold_1"    , TBool),
    CM( 0x0015, "pan_mode"  , TEnum, @["CONTINUOUS","KEY-ON"]),
    CM( 0x0016, "redamper_switch", TBool),
  ),
  CMAO("control",
    CMA(0x0017, "1", tone_control_switches),
    CMA(0x001b, "2", tone_control_switches),
    CMA(0x001f, "3", tone_control_switches),
    CMA(0x0023, "4", tone_control_switches),
  ),
  #CM( 0x0027, "reserved"),
  CMAO("wave",
    CM(0x002c, "number_l", TNibbleQuad, 0, 16384), # 0=OFF
    CM(0x0030, "number_r", TNibbleQuad, 0, 16384), # 0=OFF
    CM(0x0034, "gain", TEnum, @["-6","0","+6","+12"]),
    CMAO("fxm",
      CM(0x35, "switch", TBool),
      CM(0x36, "color", TByte, 0, 3),
      CM(0x37, "depth", TByte, 0, 16),
    ),
    CM(0x0038, "tempo_sync", TBool),
    CM(0x0039, "pitch_keyfollow", TByte, 44, 84), # -200 .. +200
  ),
  CMAO("pitch_env",
    CM( 0x003a, "depth", TByte, 52, 76), # -12 .. +12
    CM( 0x003b, "velocity_sens", TByte, 1, 127), # -63 .. +63
    CMAO("time",
      CM( 0x3c, "1_velocity_sens", TByte, 1, 127), # -63 .. +63
      CM( 0x3d, "4_velocity_sens", TByte, 1, 127), # -63 .. +63
      CM( 0x3e, "keyfollow", TByte, 54, 74), # -100 .. +100
      CM( 0x3f, "1", TByte, 0, 127),
      CM( 0x40, "2", TByte, 0, 127),
      CM( 0x41, "3", TByte, 0, 127),
      CM( 0x42, "4", TByte, 0, 127),
    ),
    CMAO("level",
      CM( 0x43, "0", TByte, 1, 127), # -63 .. +63
      CM( 0x44, "1", TByte, 1, 127), # -63 .. +63
      CM( 0x45, "2", TByte, 1, 127), # -63 .. +63
      CM( 0x46, "3", TByte, 1, 127), # -63 .. +63
      CM( 0x47, "4", TByte, 1, 127), # -63 .. +63
    ),
  ),
  CMAO("tvf",
    CM( 0x0048, "filter_type", TEnum, tvf_filter_types),
    CMAO("cutoff",
      CM( 0x0049, "frequency", TByte, 0, 127),
      CM( 0x004a, "keyfollow", TByte, 44, 84), # -200 .. +200
      CM( 0x004b, "velocity_curve", TNibble, 0, 7),
      CM( 0x004c, "velocity_sens", TByte, 1, 127), # -63 .. +63
    ),
    CMAO("resonance",
      CM( 0x004d, "q", TByte, 0, 127),
      CM( 0x004e, "velocity_sens", TByte, 1, 127), # -63 .. +63),
    ),
    CMAO("env",
      CM( 0x004f, "depth", TByte, 1, 127), # -63 .. +63
      CM( 0x0050, "velocity_curve", TByte, 0, 7),
      CM( 0x0051, "velocity_sens", TByte, 1, 127),
      CMAO("time",
        CM( 0x52, "1_velocity_sens", TByte, 1, 127),
        CM( 0x53, "4_velocity_sens", TByte, 1, 127),
        CM( 0x54, "keyfollow", TByte, 54, 74), # -100 .. +100
        CM( 0x55, "1", TByte, 0, 127),
        CM( 0x56, "2", TByte, 0, 127),
        CM( 0x57, "3", TByte, 0, 127),
        CM( 0x58, "4", TByte, 0, 127),
      ),
      CMAO("level",
        CM( 0x59, "0", TByte, 0, 127),
        CM( 0x5a, "1", TByte, 0, 127),
        CM( 0x5b, "2", TByte, 0, 127),
        CM( 0x5c, "3", TByte, 0, 127),
        CM( 0x5d, "4", TByte, 0, 127),
      ),
    ),
  ),
  CMAO("tva",
    CMAO("bias",
      CM( 0x5e, "level", TByte, 54, 74), # -100 .. +100
      CM( 0x5f, "position", TByte, 0, 127),
      CM( 0x60, "direction", TEnum, @["LOWER","UPPER","LOWER&UPPER","ALL"]),
    ),
    CMAO("level",
      CM( 0x61, "velocity_curve", TByte, 0, 7),
      CM( 0x62, "velocity_sens", TByte, 1, 127),
    ),
    CMAO("env",
      CMAO("time",
        CM( 0x63, "1_velocity_sens", TByte, 1, 127),
        CM( 0x64, "4_velocity_sens", TByte, 1, 127),
        CM( 0x65, "keyfollow", TByte),
        CM( 0x66, "1", TByte, 0, 127),
        CM( 0x67, "2", TByte, 0, 127),
        CM( 0x68, "3", TByte, 0, 127),
        CM( 0x69, "4", TByte, 0, 127),
      ),
      CMAO("level",
        CM( 0x6a, "1", TByte, 0, 127),
        CM( 0x6b, "2", TByte, 0, 127),
        CM( 0x6c, "3", TByte, 0, 127),
      ),
    ),
  ),
  CMAO("lfo",
    CMAO("1",
      CM( 0x006d, "waveform", TEnum, @["SIN","TRI","SAW-UP","SAW-DW","SQR","RND","BEND-UP","BEND-DN","TRP","S&H","CHS","VSIN","STEP"]),
      CM( 0x006e, "rate", TNibblePair, 0, 149), # 0 .. 127, MUSICAL-NOTES
      CM( 0x0070, "offset", TEnum, @["-100","-50","0","+50","+100"]),
      CM( 0x0071, "rate_detune", TByte, 0, 127),
      CMAO("delay",
        CM( 0x072,"time", TByte, 0, 127),
        CM( 0x073,"key_follow", TByte, 54, 74), # -100 .. +100
      ),
      CMAO("fade",
        CM( 0x074,"mode", TEnum, @["ON-IN","ON-OUT","OFF-IN","OFF-OUT"]),
        CM( 0x075,"time", TByte, 0, 127),
      ),
      CM( 0x0076, "key_trigger", TBool),
      CM( 0x0077, "pitch_depth", TByte, 1, 127), # -63 .. +63
      CM( 0x0078, "tvf_depth"  , TByte, 1, 127), # -63 .. +63
      CM( 0x0079, "tva_depth"  , TByte, 1, 127), # -63 .. +63
      CM( 0x007a, "pan_depth"  , TByte, 1, 127), # -63 .. +63
    ),
    CMAO("2",
      CM( 0x007b, "waveform", TEnum, @["SIN","TRI","SAW-UP","SAW-DW","SQR","RND","BEND-UP","BEND-DN","TRP","S&H","CHS","VSIN","STEP"]),
      CM( 0x007c, "rate", TNibblePair, 0, 149), # 0 .. 127, MUSICAL-NOTES
      CM( 0x007e, "offset", TEnum, @["-100","-50","0","+50","+100"]),
      CM( 0x007f, "rate_detune", TByte, 0, 127),
      CMAO("delay",
        CM( 0x100,"time", TByte),
        CM( 0x101,"key_follow", TByte, 54, 74), # -100 .. +100),
      ),
      CMAO("fade",
        CM( 0x102,"mode", TEnum, @["ON-IN","ON-OUT","OFF-IN","OFF-OUT"]),
        CM( 0x103,"time", TByte, 0, 127),
      ),
      CM( 0x0104, "key_trigger", TBool),
      CM( 0x0105, "pitch_depth", TByte, 1, 127), # -63 .. +63
      CM( 0x0106, "tvf_depth"  , TByte, 1, 127), # -63 .. +63
      CM( 0x0107, "tva_depth"  , TByte, 1, 127), # -63 .. +63
      CM( 0x0108, "pan_depth"  , TByte, 1, 127), # -63 .. +63
    ),
    CMAO("step",
      CM( 0x0109, "type", TByte, 0, 1),
      CM( 0x010a,  "1", TByte, 28, 100), # -36 .. +36
      CM( 0x010b,  "2", TByte, 28, 100), # -36 .. +36
      CM( 0x010c,  "3", TByte, 28, 100), # -36 .. +36
      CM( 0x010d,  "4", TByte, 28, 100), # -36 .. +36
      CM( 0x010e,  "5", TByte, 28, 100), # -36 .. +36
      CM( 0x010f,  "6", TByte, 28, 100), # -36 .. +36
      CM( 0x0110,  "7", TByte, 28, 100), # -36 .. +36
      CM( 0x0111,  "8", TByte, 28, 100), # -36 .. +36
      CM( 0x0112,  "9", TByte, 28, 100), # -36 .. +36
      CM( 0x0113, "10", TByte, 28, 100), # -36 .. +36
      CM( 0x0114, "11", TByte, 28, 100), # -36 .. +36
      CM( 0x0115, "12", TByte, 28, 100), # -36 .. +36
      CM( 0x0116, "13", TByte, 28, 100), # -36 .. +36
      CM( 0x0117, "14", TByte, 28, 100), # -36 .. +36
      CM( 0x0118, "15", TByte, 28, 100), # -36 .. +36
      CM( 0x0119, "16", TByte, 28, 100), # -36 .. +36
    ),
  ),
]

let drum_wmt_n = @[
  CMAO("wave",
    CM(0x00, "switch", TBool),
    #CM(0x01, "reserved"),
    CM(0x06, "number_l", TNibbleQuad, 0, 16384), # 0=OFF
    CM(0x0a, "number_r", TNibbleQuad, 0, 16384), # 0=OFF
    CM(0x0e, "gain", TEnum, @["-6","0","+6","+12"]),
    CMAO("fxm",
      CM(0x0f, "switch", TBool),
      CM(0x10, "color", TEnum, 0, 3),
      CM(0x11, "depth", TEnum, 0, 16),
    ),
    CM(0x12, "tempo_sync", TBool),
    CM(0x13, "coarse_tune", TByte, 16, 112), # -48 .. +48
    CM(0x14, "fine_tune", TByte, 14, 114), # -50 .. +50
    CM(0x15, "pan", TByte, 0, 127),
    CM(0x16, "random_pan_switch", TBool),
    CM(0x17, "alt_pan_switch", TEnum, @["OFF","ON","REVERSE"]),
    CM(0x18, "level", TByte, 0, 127),
  ),
  CMA( 0x19, "velocity", velocity_ranges),
]

let drum_tone_n = @[
  CM(0x00, "name", TName),
  CM(0x0c, "assign_single", TBool),
  CM(0x0d, "mute_group", TByte, 0, 31), # 0=OFF
  CM(0x0e, "level", TByte, 0, 127),
  CM(0x0f, "coarse_tune", TByte, 0, 127),
  CM(0x10, "fine_tune", TByte, 14, 114), # -50 .. +50
  CM(0x11, "random_pitch_depth", TEnum, random_pitch_depth_values),
  CM(0x12, "pan", TByte, 0, 127),
  CM(0x13, "random_pan_depth", TByte, 0, 63),
  CM(0x14, "alt_pan_depth", TByte, 1, 127),
  CM(0x15, "env_sustain", TByte, 0, 127),
  CM(0x16, "dry_send"   , TByte, 0, 127),
  CM(0x17, "chorus_send", TByte, 0, 127),
  CM(0x18, "reverb_send", TByte, 0, 127),
  CM(0x19, "chorus_send", TByte, 0, 127),
  CM(0x1a, "reverb_send", TByte, 0, 127),
  CM(0x1b, "output_assign", TEnum, @["MFX","A","---","---","---", $1, $2, "---","---","---","---","---","---"]),
  CM(0x1c, "bend_range", TByte, 0, 48),
  CMAO("rx",
    CM(0x1d, "expression", TBool),
    CM(0x1e, "hold_1"    , TBool),
    CM(0x1f, "pan_mode", TEnum, @["CONTINUOUS","KEY-ON"]),
  ),
  CMAO("wmt",
    CM(0x20, "velocity_control", TEnum, @["OFF","ON","RANDOM"]),
    CMA(0x21, "1", drum_wmt_n),
    CMA(0x3e, "2", drum_wmt_n),
    CMA(0x5b, "3", drum_wmt_n),
    CMA(0x78, "4", drum_wmt_n),
  ),
  CMAO("pitch_env",
    CM(0x115, "depth", TByte, 52, 76), # -12 .. +12
    CM(0x116, "velocity_sens", TByte, 1, 127), # -63 .. +63
    CMAO("time",
      CM(0x117, "1_velocity_sens", TByte, 1, 127), # -63 .. +63
      CM(0x118, "4_velocity_sens", TByte, 1, 127), # -63 .. +63
      CM(0x119, "1", TByte, 0, 127),
      CM(0x11a, "2", TByte, 0, 127),
      CM(0x11b, "3", TByte, 0, 127),
      CM(0x11c, "4", TByte, 0, 127),
    ),
    CMAO("level",
      CM(0x11d, "0", TByte, 1, 127), # -63 .. +63
      CM(0x11e, "1", TByte, 1, 127), # -63 .. +63
      CM(0x11f, "2", TByte, 1, 127), # -63 .. +63
      CM(0x120, "3", TByte, 1, 127), # -63 .. +63
      CM(0x121, "4", TByte, 1, 127), # -63 .. +63
    ),
  ),
  CMAO("tvf",
    CM(0x122, "filter_type", TEnum, tvf_filter_types),
    CMAO("cutoff",
      CM(0x123, "frequency", TByte, 0, 127),
      CM(0x124, "velocity_curve", TNibble, 0, 7),
      CM(0x125, "velocity_sens", TByte, 1, 127), # -63 .. +63
    ),
    CMAO("resonance",
      CM(0x126, "q", TByte, 0, 127),
      CM(0x127, "velocity_sens", TByte, 1, 127), # -63 .. +63
    ),
    CMAO("env",
      CM(0x128, "depth", TByte, 1, 127), # -63 .. +63
      CM(0x129, "velocity_curve", TByte, 0, 7),
      CM(0x12a, "velocity_sens", TByte, 1, 127),
      CMAO("time",
        CM(0x12b, "1_velocity_sens", TByte, 1, 127), # -63 .. +63
        CM(0x12c, "4_velocity_sens", TByte, 1, 127), # -63 .. +63
        CM(0x12d, "1", TByte, 0, 127),
        CM(0x12e, "2", TByte, 0, 127),
        CM(0x12f, "3", TByte, 0, 127),
        CM(0x130, "4", TByte, 0, 127),
      ),
      CMAO("level",
        CM(0x131, "0", TByte, 0, 127),
        CM(0x132, "1", TByte, 0, 127),
        CM(0x133, "2", TByte, 0, 127),
        CM(0x134, "3", TByte, 0, 127),
        CM(0x135, "4", TByte, 0, 127),
      ),
    ),
  ),
  CMAO("tva",
    CMAO("level",
      CM(0x136, "velocity_curve", TByte, 0, 7),
      CM(0x137, "velocity_sens", TByte, 1, 127),
    ),
    CMAO("env",
      CMAO("time",
        CM(0x138, "1_velocity_sens", TByte, 1, 127),
        CM(0x139, "4_velocity_sens", TByte, 1, 127),
        CM(0x13a, "1", TByte, 0, 127),
        CM(0x13b, "2", TByte, 0, 127),
        CM(0x13c, "3", TByte, 0, 127),
        CM(0x13d, "4", TByte, 0, 127),
      ),
      CMAO("level",
        CM(0x13e, "1", TByte, 0, 127),
        CM(0x13f, "2", TByte, 0, 127),
        CM(0x140, "3", TByte, 0, 127),
      ),
    ),
  ),
  CM(0x141, "one_shot_mode", TBool),
  CM(0x142, "relative_level", TByte, 0, 127),
]
proc generate_drum_tones(): MemArea =
  for i in 21..108:
    let k = 0x1000 + (0x200 * (i - 21))
    let a = ((k and 0x8000) shl 1) or (k and 0x7fff)
    result.add( CMA(JAddr(a), $i, drum_tone_n) )
let drum_tones = generate_drum_tones()

let patch = @[
  CMAO("common",
    CM(       0x00, "name", TName),
    CM(       0x0c, "category", TByte, 0, 127),
    #CM(       0x0d, "reserved_1"),
    CM(       0x0e, "level", TByte, 0, 127),
    CM(       0x0f, "pan", TByte, 0, 127),
    CM(       0x10, "priority", TEnum),
    CM(       0x11, "coarse_tune", TByte),
    CM(       0x12, "fine_tune", TByte),
    CM(       0x13, "octave_shift", TByte),
    CM(       0x14, "stretch_tune_depth", TEnum),
    CM(       0x15, "analog_feel", TByte, 0, 127),
    CM(       0x16, "mono_poly", TBool),
    CM(       0x17, "legato_switch", TBool),
    CM(       0x18, "legato_retrigger", TBool),
    CMAO("portamento",
      CM(     0x19, "switch", TByte),
      CM(     0x1a, "mode", TEnum),
      CM(     0x1b, "type", TEnum),
      CM(     0x1c, "start", TEnum),
      CM(     0x1d, "time", TByte, 0, 127),
    ),
    #CM(       0x1e, "reserved_2"),
    CM(       0x22, "cutoff_offset"   , TByte, 1, 127), # -63 .. +63
    CM(       0x23, "resonance_offset", TByte, 1, 127), # -63 .. +63
    CM(       0x24, "attack_offset"   , TByte, 1, 127), # -63 .. +63
    CM(       0x25, "release_offset"  , TByte, 1, 127), # -63 .. +63
    CM(       0x26, "velocity_offset" , TByte, 1, 127), # -63 .. +63
    CM(       0x27, "output_assign", TEnum, @["MFX","A","---","---","---", $1, $2, "---","---","---","---","---","---","TONE"]),
    CM(       0x28, "tmt_control_switch", TBool),
    CM(       0x29, "bend_range_up"  , TByte, 0, 48),
    CM(       0x2a, "bend_range_down", TByte, 0, 48),
    CMAO("matrix_control",
      CMA(    0x2b, "1", matrix_control),
      CMA(    0x34, "2", matrix_control),
      CMA(    0x3d, "3", matrix_control),
      CMA(    0x46, "4", matrix_control),
    ),
    CM(       0x4f, "modulation_switch", TBool),
    CMA(  0x000200, "mfx", mfx),
    CMA(  0x000400, "chorus", chorus),
    CMA(  0x000600, "reverb", reverb),
  ),
  CMA(    0x001000, "tmt", tmt),
  CMAO("tone",
    CMA(  0x002000, "1", patch_tone_n),
    CMA(  0x002200, "2", patch_tone_n),
    CMA(  0x002400, "3", patch_tone_n),
    CMA(  0x002600, "4", patch_tone_n),
  ),
]

let drum_kit = @[
  CMAO("common",
    CM(       0x00, "name", TName),
    CM(       0x0c, "level", TByte, 0, 127),
    #CM(       0x0d, "reserved"),
    CM(       0x11, "output_assign", TEnum, @["MFX","A","---","---","---", $1, $2, "---","---","---","---","---","---","TONE"]),
  ),
  CMA(    0x000200, "mfx", mfx),
  CMA(    0x000400, "chorus", chorus),
  CMA(    0x000600, "reverb", reverb),
  CMAO("tone", drum_tones),
]

let patch_drum = @[
  CMA(0x00000000, "patch", patch ),
  CMA(0x00100000, "drum", drum_kit ),
]

let arpeggio_steps = Mem(kind: TNibblePair, low: 0, high: 128).repeat(32, 2)
let arpeggio_pattern = @[
  CM(0x0000, "original_note", TByte),
  CMAO("step", arpeggio_steps),
]
let arpeggio_patterns = arpeggio_pattern.repeat(16, 0x100)
let arpeggio = @[
  CM( 0x0000, "end_step", TByte, 1, 32),
  CM( 0x0002, "name", TName16),
  #CM( 0x0012, "reserved"),
  CMA(0x1000, "pattern_note", arpeggio_patterns),
]

let pad = @[
  CM(0, "velocity", TByte, 1, 127),
  CM(2, "pattern_number", TNibblePair, 0, 255),
]
let pads = pad.repeat(8, 2)
let rhythm_group = @[
  CM(0x00, "name", TName16),
  CM(0x10, "bank_msb", TByte, 0, 127),
  CM(0x11, "bank_lsb", TByte, 0, 127),
  CM(0x12, "pc"      , TByte, 0, 127),
  #CM(0x13, "reserved_1"),
  CMA(0x15, "pad", pads),
  #CM(0x71, "reserved_2"),
  #CM(0x72, "reserved_3"),
]

let auto_pitch_key_values= @[
  "C","Db","D","Eb","E","F","F#","G","Ab","A","Bb","B",
  "Cm","C#m","Dm","D#m","Em","Fm","F#m","Gm","G#m","A","Bbm","B",
]
let auto_pitch_note_values = @["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
let vocal_effect = @[
  CM(0x00, "name", TName),
  CM(0x0c, "type", TEnum, @["Vocoder","Auto-Pitch"]),
  #CM(0x0d, "reserved_1"),
  CM(0x0e, "bank_msb", TByte, 0, 127),
  CM(0x0f, "bank_lsb", TByte, 0, 127),
  CM(0x10, "pc"      , TByte, 0, 127),
  CM(0x11, "level"   , TByte, 0, 127),
  CM(0x12, "pan"     , TByte, 0, 127),
  #CM(0x13, "reserved_2"),
  CMAO("auto_pitch",
    CM(0x16, "type"   , TEnum, @["SOFT","HARD","ELECTRIC1","ELECTRIC2","ROBOT"]),
    CM(0x17, "scale"  , TEnum, @["CHROMATIC","Maj(Min)"]),
    CM(0x18, "key"    , TEnum, auto_pitch_key_values),
    CM(0x19, "note"   , TEnum, auto_pitch_note_values),
    CM(0x1a, "gender" , TByte, 0, 20), # -10 .. +10
    CM(0x1b, "octave" , TByte, 0, 2), # -1 .. +1
    CM(0x1c, "balance", TByte, 0, 100),
  ),
  CMAO("vocoder",
    CM(0x1d, "envelope", TEnum, @["SHARP","SOFT","LONG"]),
    CM(0x1e, "mic_sens", TByte, 0, 127),
    CM(0x1f, "synth_level", TByte, 0, 127),
    CM(0x20, "mic_mix", TByte, 0, 127),
    CM(0x21, "mic_hpf", TEnum, @["BYPASS", "1000", "1250", "1600", "2000", "2500", "3150", "4000", "5000", "6300", "8000", "10000", "12500", "16000"]),
  ),
  CM(0x22, "part_level", TByte, 0, 127),
]

let source_values = @["PERFORM", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16]
let voice_reserves = Mem(kind: TByte, low: 0, high: 64).repeat(16, 1)
let midis = midi_n.repeat(16, 0x100)
let parts = part_n.repeat(16, 0x100)
let zones = zone_n.repeat(16, 0x100)
let performance_pattern = @[
  CMAO("common",
    CM(  0x00, "name", TName),
    CM(  0x0c, "solo", TBool),
    CM(  0x0d, "mfx1_channel", TByte, 0, 16), # 16=OFF
    #CM(  0x0e, "reserved_1"),
    #CM(  0x0f, "reserved_2"),
    CMA( 0x10, "voice_reserve", voice_reserves),
    #CM(  0x20, "reserved_3"),
    CM(  0x30, "mfx1_source"  , TEnum, source_values),
    CM(  0x31, "mfx2_source"  , TEnum, source_values),
    CM(  0x32, "mfx3_source"  , TEnum, source_values),
    CM(  0x33, "chorus_source", TEnum, source_values),
    CM(  0x34, "reverb_source", TEnum, source_values),
    CM(  0x35, "mfx2_channel" , TByte, 0, 16),
    CM(  0x36, "mfx3_channel" , TByte, 0, 16),
    CM(  0x37, "mfx_structure", TByte, 0, 15),
  ),
  CMA( 0x0200, "mfx1", mfx),
  CMA( 0x0400, "chorus", chorus),
  CMA( 0x0600, "reverb", reverb),
  CMA( 0x0800, "mfx2", mfx),
  CMA( 0x0a00, "mfx3", mfx),
  CMA( 0x1000, "midi", midis),
  CMA( 0x2000, "part", parts),
  CMA( 0x5000, "zone", zones),
  CMA( 0x6000, "controller",
    #CM(  0x00, "reserved_1"),
    CM(  0x18, "arp_zone_number", TByte, 0, 15),
    #CM(  0x19, "reserved_1"),
    CM(  0x54, "recommended_tempo", TNibblePair, 20, 250),
    #CM(  0x56, "reserved_2"),
    #CM(  0x59, "reserved_3"),
  ),
]

let setup = @[
  CM(     0x00, "sound_mode", TEnum, @["PATCH","PERFORM","GM1","GM2","GS"]),
  CMAO("performance",
    CM(   0x01, "bank_msb", TByte, 0, 127),
    CM(   0x02, "bank_lsb", TByte, 0, 127),
    CM(   0x03, "pc"      , TByte, 0, 127),
  ),
  CMAO("kbd_patch",
    CM(   0x04, "bank_msb", TByte, 0, 127),
    CM(   0x06, "bank_lsb", TByte, 0, 127),
    CM(   0x07, "pc"      , TByte, 0, 127),
  ),
  CMAO("rhy_patch",
    CM(   0x07, "bank_msb", TByte, 0, 127),
    CM(   0x08, "bank_lsb", TByte, 0, 127),
    CM(   0x09, "pc"      , TByte, 0, 127),
    CM(   0x0a, "mfx1_switch"  , TBool),
    CM(   0x0b, "mfx2_switch"  , TBool),
    CM(   0x0c, "mfx3_switch"  , TBool),
    CM(   0x0d, "chorus_switch", TBool),
    CM(   0x0e, "reverb_switch", TBool),
    #CM(   0x0f, "reserved_1"),
    CM(   0x12, "transpose"   , TByte, 59, 70), # -5 .. +6
    CM(   0x13, "octave_shift", TByte, 61, 67), # -3 .. +3
    #CM(   0x14, "reserved_4"),
    CM(   0x15, "knob_select", TByte, 0, 2),
    #CM(   0x16, "reserved_5"),
    CMAO("arpeggio",
      CM( 0x17, "grid"    , TEnum, @["04_","08_","08L","08H","08t","16_","16L","16H","16t"]),
      CM( 0x18, "duration", TEnum, @["30","40","50","60","70","80","90","100","120","FUL"]),
      CM( 0x19, "switch", TBool),
      #CM( 0x1a, "reserved_6"),
      CM( 0x1b, "style", TByte, 0, 127),
      CM( 0x1c, "motif", TEnum, @["UP/L","UP/H","UP/_","dn/L","dn/H","dn/_","Ud/L","Ud/H","Ud/_","rn/L"]),
      CM( 0x1d, "octave_range", TByte, 61, 67), # -3 .. +3
      CM( 0x1e, "hold", TBool),
      CM( 0x1f, "accent", TByte, 0, 100),
      CM( 0x20, "velocity", TByte, 0, 127),
    ),
    CMAO("rhythm",
      CM( 0x21, "switch", TBool),
      #CM( 0x22, "reserved_7"),
      CM( 0x23, "style", TNibblePair, 0, 255),
      #CM( 0x25, "reserved_8"),
      CM( 0x26, "group"   , TByte, 0, 29),
      CM( 0x27, "accent"  , TByte, 0, 100),
      CM( 0x28, "velocity", TByte, 1, 127),
      #CM( 0x29, "reserved_9"),
    ),
    CM(   0x33, "arpeggio_step", TByte, 0, 32),
  ),
]

let polarity = @["STANDARD","REVERSE"]
let pedal_assign_values = @[
  "MODULATION",
  "PORTA-TIME",
  "VOLUME",
  "PAN",
  "EXPRESSION",
  "HOLD",
  "PORTAMENTO",
  "SOSTENUTO",
  "RESONANCE",
  "RELEASE-TIME",
  "ATTACK-TIME",
  "CUTOFF",
  "DECAY-TIME",
  "VIB-RATE",
  "VIB-DEPTH",
  "VIB-DELAY",
  "CHO-SEND-LEVEL",
  "REV-SEND-LEVEL",
  "AFTERTOUCH",
  "START/STOP",
  "TAP-TEMPO",
  "PROG-UP",
  "PROG-DOWN",
  "FAV-UP",
  "FAV-DOWN",
]
let knob_assign_values = control_source_values & @[
  "EQ-LOW-FREQ",
  "EQ-LOW-GAIN",
  "EQ-MID-FREQ",
  "EQ-MID-GAIN",
  "EQ-MID-Q",
  "EQ-HIGH-FREQ",
  "EQ-HIGH-GAIN",
]

let system = @[
  CMA(0x000000, "common",
    CMA(0x0000, "master",
      CM( 0x00, "tune", TNibbleQuad, 24, 2024), # -100 .. +100
      CM( 0x04, "key_shift", TByte, 40, 88),    #  -24 .. +24
      CM( 0x05, "level", TByte, 0, 127),
    ),
    CM(   0x06, "scale_switch", TBool),
    CM(   0x07, "patch_remain", TBool),
    CM(   0x08, "mix_parallel", TBool),
    CM(   0x09, "control_channel", TByte, 0, 16), # 16=OFF
    CM(   0x0a, "kbd_patch_channel", TByte, 0, 15),
    #CM(   0x0b, "reserved_1", TBool),
    CMA(  0x0c, "scale", scale_map),
    CMAO("control_source",
      CM( 0x18, "1", TEnum, control_source_values),
      CM( 0x19, "2", TEnum, control_source_values),
      CM( 0x1a, "3", TEnum, control_source_values),
      CM( 0x1b, "4", TEnum, control_source_values),
    ),
    CMAO("rx",
      CM( 0x1c, "pc"  , TBool),
      CM( 0x1d, "bank", TBool),
    ),
  ),
  CMA(0x004000, "controller",
    CMAO("tx",
      CM( 0x00, "pc"  , TBool),
      CM( 0x01, "bank", TBool),
    ),
    CM(   0x02, "velocity", TByte, 0, 127), # 0=REAL
    CM(   0x03, "velocity_curve", TEnum, @["LIGHT","MEDIUM","HEAVY"]),
    #CM(   0x04, "reserved_1"),
    CM(   0x05, "hold_polarity", TEnum, polarity),
    CM(   0x06, "continuous_hold", TBool),
    CMAO("control_pedal",
      CM( 0x07, "assign"  , TEnum, pedal_assign_values),
      CM( 0x08, "polarity", TEnum, polarity),
    ),
    #CM(   0x09, "reserved_2"),
    CMAO("knob_assign",
      CM( 0x10, "1", TByte, knob_assign_values),
      CM( 0x11, "2", TByte, knob_assign_values),
      CM( 0x12, "3", TByte, knob_assign_values),
      CM( 0x13, "4", TByte, knob_assign_values),
    ),
    #CM(   0x14, "reserved_2"),
    #CM(   0x4d, "reserved_3"),
  ),
]

let performance_patterns = performance_pattern.repeat(128, 0x010000)
let performance_patches = patch.repeat(256, 0x10000)
let vocal_effects = vocal_effect.repeat(20, 0x100)
let drum_kits = drum_kit.repeat(8, 0x100000)
let juno_map* = CMAO("",
  CMA(    0x01000000, "setup", setup),
  CMA(    0x02000000, "system", system),
  CMA(    0x10000000, "temporary",
    CMA(  0x00000000, "performance_pattern", performance_pattern),
    CMAO("performance_part",
      CMA(0x01000000,  "1", patch_drum), # Temporary Patch/Drum (Performance Mode Part 1)
      CMA(0x01200000,  "2", patch_drum),
      CMA(0x01400000,  "3", patch_drum),
      CMA(0x01600000,  "4", patch_drum),
      CMA(0x02000000,  "5", patch_drum),
      CMA(0x02200000,  "6", patch_drum),
      CMA(0x02400000,  "7", patch_drum),
      CMA(0x02600000,  "8", patch_drum),
      CMA(0x03000000,  "9", patch_drum),
      CMA(0x03200000, "10", patch_drum),
      CMA(0x03400000, "11", patch_drum),
      CMA(0x03600000, "12", patch_drum),
      CMA(0x04000000, "13", patch_drum),
      CMA(0x04200000, "14", patch_drum),
      CMA(0x04400000, "15", patch_drum),
      CMA(0x04600000, "16", patch_drum),
    ),
    CMA(  0x0e000000, "rhythm_pattern", arpeggio),
    CMA(  0x0e110000, "arpeggio", arpeggio),
    CMA(  0x0e130000, "rhythm_group", rhythm_group),
    CMA(  0x0e150000, "vocal_effect", vocal_effect),
    CMA(  0x0f000000, "patch_part", # patch mode part 1
      CMA(0x00000000, "1", patch_drum),
      CMA(0x00200000, "2", patch_drum),
    ),
  ),
  CMA(  0x20000000, "user",
    CMA(0x00000000, "performance", performance_patterns),
    CMA(0x01000000, "pattern"    , performance_patterns),
    CMA(0x10000000, "patch"      , performance_patches),
    CMA(0x20000000, "drum_kit", drum_kits),
    CMA(0x40000000, "vocal_effect", vocal_effects),
  ),
)

