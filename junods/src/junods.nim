import strutils

type
  Kind = enum
    TNone,
    TBool,
    TNibble,
    TEnum,
    TByte,
    TNibblePair,
    TNibbleQuad,
    TName,
    TName16,
  JAddr = int64
const NOFF: JAddr = -1

type
  Mem = ref object # tree structure for describing areas of device memory
    offset: JAddr
    kind:   Kind
    name:   string
    area*:  seq[Mem]
  MemArea = seq[Mem]


proc normalize*(offset: JAddr): JAddr =
  if offset == NOFF:
    return offset
  let n3: JAddr = (offset and 0x7f000000)
  let n2: JAddr = (offset and 0x007f0000) or ((offset and 0x00800000) shl 1)
  let n1: JAddr = (offset and 0x00007f00) or ((offset and 0x00008000) shl 1)
  let n0: JAddr = (offset and 0x0000007f) or ((offset and 0x00000080) shl 1)
  return (n3 or n2 or n1 or n0) and 0x7f7f7f7f

proc `+=`*(n1: var JAddr, n2: JAddr) =
  n1 = normalize(n1 + n2)

proc CM(offset: JAddr, name: string, kind: Kind = TNone): Mem =
  Mem(offset: normalize(offset), name: name, kind: kind)

proc CMA(offset: JAddr, name: string, area: varargs[Mem]): Mem =
  Mem(offset: normalize(offset), name: name, area: @area)

proc CMAO(name: string, area: varargs[Mem]): Mem =
  CMA(NOFF, name, area)

proc repeat(thing: MemArea, n, span: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    result.add(CMA(JAddr(span * i), $(i + 1), thing))

proc repeat(kind: Kind, n, span: int): seq[Mem] =
  result = newSeqOfCap[Mem](n)
  for i in 0..<n:
    result.add(CM(JAddr(span * i), $(i + 1), kind))

let scale_map = @[
  CM(0x00, "c" , TByte),
  CM(0x01, "c#", TByte),
  CM(0x02, "d" , TByte),
  CM(0x03, "d#", TByte),
  CM(0x04, "e" , TByte),
  CM(0x05, "f" , TByte),
  CM(0x06, "f#", TByte),
  CM(0x07, "g" , TByte),
  CM(0x08, "g#", TByte),
  CM(0x09, "a" , TByte),
  CM(0x0a, "a#", TByte),
  CM(0x0b, "b" , TByte),
]

let controls = @[
  CM(0, "source", TEnum),
  CM(1, "sens"  , TByte),
]
let control = controls.repeat(4, 2) & @[
  CMA(8, "assign", TEnum.repeat(4,1))
]

let parameters_20 = TNibbleQuad.repeat(20, 4)
let parameters_32 = TNibbleQuad.repeat(32, 4)

let mfx = @[
  CM( 0x00, "type", TEnum),
  CM( 0x01, "dry_send", TEnum),
  CM( 0x02, "chorus_send", TEnum),
  CM( 0x03, "reverb_send", TEnum),
  CM( 0x04, "output_asssign", TEnum),
  CMA(0x05, "control", control),
  CMA(0x11, "parameter", parameters_32),
]

let chorus = @[
  CM( 0x00, "type", TEnum),
  CM( 0x01, "level", TByte),
  CM( 0x02, "output_assign", TEnum),
  CM( 0x03, "output_select", TEnum),
  CMA(0x04, "parameter", parameters_20),
]
let reverb = @[
  CM( 0x00, "type", TEnum),
  CM( 0x01, "level", TByte),
  CM( 0x02, "output_assign", TEnum),
  CMA(0x03, "parameter", parameters_20),
]

let midi_n = @[
  CMAO("rx",
    CM(0x00, "pc"),
    CM(0x01, "bank"),
    CM(0x02, "bend"),
    CM(0x03, "key_pressure"),
    CM(0x04, "channel_pressure"),
    CM(0x05, "modulation"),
    CM(0x06, "volume"),
    CM(0x07, "pan"),
    CM(0x08, "expression"),
    CM(0x09, "hold_1"),
  ),
  CM(0x0a, "phase_lock"),
  CM(0x0b, "velocity_curve_type"),
]

let part_n = @[
  CM(0x00, "rx_channel", TNibble),
  CM(0x01, "rx_switch", TByte),
  CM(0x02, "reserved_1"),
  CM(0x04, "patch_bank_msb", TByte),
  CM(0x05, "patch_bank_lsb", TByte),
  CM(0x06, "patch_pc", TByte),
  CM(0x07, "level", TByte),
  CM(0x08, "pan", TByte),
  CM(0x09, "coarse_tune", TByte),
  CM(0x0a, "fine_tune", TByte),
  CM(0x0b, "mono_poly", TEnum),
  CM(0x0c, "legato", TEnum),
  CM(0x0d, "bend_range", TByte),
  CM(0x0e, "portamento_switch", TEnum),
  CM(0x0f, "portamento_time", TNibblePair),
  CM(0x11, "cutoff_offset", TByte),
  CM(0x12, "resonance_offset", TByte),
  CM(0x13, "attack_offset", TByte),
  CM(0x14, "release_offset", TByte),
  CM(0x15, "octave_shift", TByte),
  CM(0x16, "velocity_sens_offset", TByte),
  CM(0x17, "reserved_2"),
  CM(0x1b, "mute", TBool),
  CM(0x1c, "dry_send", TByte),
  CM(0x1d, "chorus_send", TByte),
  CM(0x1e, "reverb_send", TByte),
  CM(0x1f, "output_assign", TEnum),
  CM(0x20, "output_mfx_select", TEnum),
  CM(0x21, "decay_offset", TByte),
  CM(0x22, "vibrato_rate", TByte),
  CM(0x23, "vibrato_depth", TByte),
  CM(0x24, "vibrato_delay", TByte),
  CMA(0x25, "scale", scale_map),
]

let zone_n = @[
  CM(0x00, "octave_shift", TByte),
  CM(0x01, "switch", TBool),
  CM(0x02, "reserved_1"),
  CM(0x0c, "range_lower", TByte),
  CM(0x0d, "range_upper", TByte),
  CM(0x0e, "reserved_2"),
  CM(0x1a, "reserved_3"),
]

let matrix_control = @[
  CM(0, "source", TEnum),
  CM(1, "destination_1", TEnum),
  CM(2, "sens_1", TByte),
  CM(3, "destination_2", TEnum),
  CM(4, "sens_2", TByte),
  CM(5, "destination_3", TEnum),
  CM(6, "sens_3", TByte),
  CM(7, "destination_4", TEnum),
  CM(8, "sens_4", TByte),
]

let ranges = @[
  CM(0, "range_lower", TByte),
  CM(1, "range_upper", TByte),
  CM(2, "fade_lower", TByte),
  CM(3, "fade_upper", TByte),
]
let tmt_n = @[
  CM(0, "tone_switch", TBool),
  CMA(1, "keyboard", ranges),
  CMA(5, "velocity", ranges),
]
let tmt = @[
  CMAO("1-2",
    CM(0x00, "structure_type", TEnum),
    CM(0x01, "booster", TEnum),
  ),
  CMAO("3-4",
    CM(0x02, "structure_type", TEnum),
    CM(0x03, "booster", TEnum),
  ),
  CM(0x04, "velocity_control", TEnum),
  CMA(0x05, "1", tmt_n),
  CMA(0x0e, "2", tmt_n),
  CMA(0x17, "3", tmt_n),
  CMA(0x20, "4", tmt_n),
]

let tone_control_switches = @[
  CMAO("switch",
    CM( 0, "1", TEnum),
    CM( 1, "2", TEnum),
    CM( 2, "3", TEnum),
    CM( 3, "4", TEnum),
  ),
]

let patch_tone_n = @[
  CM( 0x0000, "level", TByte),
  CM( 0x0001, "coarse_tune", TByte),
  CM( 0x0002, "fine_tune", TByte),
  CM( 0x0003, "random_pitch_depth", TEnum),
  CM( 0x0004, "pan", TByte),
  CM( 0x0005, "pan_keyfollow", TEnum),
  CM( 0x0006, "random_pan_depth", TByte),
  CM( 0x0007, "alt_pan_depth", TByte),
  CM( 0x0008, "env_sustain", TByte),
  CM( 0x0009, "delay_mode", TEnum),
  CM( 0x000a, "delay_time", TNibblePair),
  CM( 0x000c, "dry_send", TByte),
  CM( 0x000d, "chorus_send_mfx", TByte),
  CM( 0x000e, "reverb_send_mfx", TByte),
  CM( 0x000f, "chorus_send", TByte),
  CM( 0x0010, "reverb_send", TByte),
  CM( 0x0011, "output_assign", TEnum),
  CMAO("rx",
    CM( 0x0012, "bend", TBool),
    CM( 0x0013, "expression", TBool),
    CM( 0x0014, "hold_1", TBool),
    CM( 0x0015, "pan_mode", TEnum),
    CM( 0x0016, "redamper_switch", TBool),
  ),
  CMAO("control",
    CMA(0x0017, "1", tone_control_switches),
    CMA(0x001b, "2", tone_control_switches),
    CMA(0x001f, "3", tone_control_switches),
    CMA(0x0023, "4", tone_control_switches),
  ),
  CM( 0x0027, "reserved"),
  CMAO("wave",
    CM(0x002c, "number_l", TNibbleQuad),
    CM(0x0030, "number_r", TNibbleQuad),
    CM(0x0034, "gain", TByte),
    CMAO("fxm",
      CM(0x35, "switch", TBool),
      CM(0x36, "color", TEnum),
      CM(0x37, "depth", TByte),
    ),
    CM(0x0038, "tempo_sync", TBool),
    CM(0x0039, "pitch_keyfollow", TByte),
  ),
  CMAO("pitch_env",
    CM( 0x003a, "depth", TByte),
    CM( 0x003b, "velocity_sens", TByte),
    CMAO("time",
      CM( 0x3c, "1_velocity_sens", TByte),
      CM( 0x3d, "4_velocity_sens", TByte),
      CM( 0x3e, "keyfollow", TByte),
      CM( 0x3f, "1", TByte),
      CM( 0x40, "2", TByte),
      CM( 0x41, "3", TByte),
      CM( 0x42, "4", TByte),
    ),
    CMAO("level",
      CM( 0x43, "0", TByte),
      CM( 0x44, "1", TByte),
      CM( 0x45, "2", TByte),
      CM( 0x46, "3", TByte),
      CM( 0x47, "4", TByte),
    ),
  ),
  CMAO("tvf",
    CM( 0x0048, "filter_type", TEnum),
    CMAO("cutoff",
      CM( 0x0049, "frequency", TByte),
      CM( 0x004a, "keyfollow", TByte),
      CM( 0x004b, "velocity_curve", TByte),
      CM( 0x004c, "velocity_sens", TByte),
    ),
    CMAO("resonance",
      CM( 0x004d, "q", TByte),
      CM( 0x004e, "velocity_sens", TByte),
    ),
    CMAO("env",
      CM( 0x004f, "depth", TByte),
      CM( 0x0050, "velocity_curve", TByte),
      CM( 0x0051, "velocity_sens", TByte),
      CMAO("time",
        CM( 0x52, "1_velocity_sens", TByte),
        CM( 0x53, "4_velocity_sens", TByte),
        CM( 0x54, "keyfollow", TByte),
        CM( 0x55, "1", TByte),
        CM( 0x56, "2", TByte),
        CM( 0x57, "3", TByte),
        CM( 0x58, "4", TByte),
      ),
      CMAO("level",
        CM( 0x59, "0", TByte),
        CM( 0x5a, "1", TByte),
        CM( 0x5b, "2", TByte),
        CM( 0x5c, "3", TByte),
        CM( 0x5d, "4", TByte),
      ),
    ),
  ),
  CMAO("tva",
    CMAO("bias",
      CM( 0x5e, "level", TByte),
      CM( 0x5f, "position", TByte),
      CM( 0x60, "direction", TEnum),
    ),
    CMAO("level",
      CM( 0x61, "velocity_curve", TByte),
      CM( 0x62, "velocity_sens", TByte),
    ),
    CMAO("env",
      CMAO("time",
        CM( 0x63, "1_velocity_sens", TByte),
        CM( 0x64, "4_velocity_sens", TByte),
        CM( 0x65, "keyfollow", TByte),
        CM( 0x66, "1", TByte),
        CM( 0x67, "2", TByte),
        CM( 0x68, "3", TByte),
        CM( 0x69, "4", TByte),
      ),
      CMAO("level",
        CM( 0x6a, "1", TByte),
        CM( 0x6b, "2", TByte),
        CM( 0x6c, "3", TByte),
      ),
    ),
  ),
  CMAO("lfo",
    CMAO("1",
      CM( 0x006d, "waveform", TEnum),
      CM( 0x006e, "rate", TNibblePair),
      CM( 0x0070, "offset", TEnum),
      CM( 0x0071, "rate_detune", TByte),
      CMAO("delay",
        CM( 0x072,"time", TByte),
        CM( 0x073,"key_follow", TByte),
      ),
      CMAO("fade",
        CM( 0x074,"mode", TEnum),
        CM( 0x075,"time", TByte),
      ),
      CM( 0x0076, "key_trigger", TBool),
      CM( 0x0077, "pitch_depth", TByte),
      CM( 0x0078, "tvf_depth", TByte),
      CM( 0x0079, "tva_depth", TByte),
      CM( 0x007a, "pan_depth", TByte),
    ),
    CMAO("2",
      CM( 0x007b, "waveform", TEnum),
      CM( 0x007c, "rate", TNibblePair),
      CM( 0x007e, "offset", TEnum),
      CM( 0x007f, "rate_detune", TByte),
      CMAO("delay",
        CM( 0x100,"time", TByte),
        CM( 0x101,"key_follow", TByte),
      ),
      CMAO("fade",
        CM( 0x102,"mode", TEnum),
        CM( 0x103,"time", TByte),
      ),
      CM( 0x0104, "key_trigger", TBool),
      CM( 0x0105, "pitch_depth", TByte),
      CM( 0x0106, "tvf_depth", TByte),
      CM( 0x0107, "tva_depth", TByte),
      CM( 0x0108, "pan_depth", TByte),
    ),
    CMAO("step",
      CM( 0x0109, "type", TByte),
      CM( 0x010a, "1", TByte),
      CM( 0x010b, "2", TByte),
      CM( 0x010c, "3", TByte),
      CM( 0x010d, "4", TByte),
      CM( 0x010e, "5", TByte),
      CM( 0x010f, "6", TByte),
      CM( 0x0110, "7", TByte),
      CM( 0x0111, "8", TByte),
      CM( 0x0112, "9", TByte),
      CM( 0x0113, "10", TByte),
      CM( 0x0114, "11", TByte),
      CM( 0x0115, "12", TByte),
      CM( 0x0116, "13", TByte),
      CM( 0x0117, "14", TByte),
      CM( 0x0118, "15", TByte),
      CM( 0x0119, "16", TByte),
    ),
  ),
]

let drum_wmt_n = @[
  CMAO("wave",
    CM(0x00, "switch", TBool),
    CM(0x01, "reserved"),
    CM(0x06, "number_l", TNibbleQuad),
    CM(0x0a, "number_r", TNibbleQuad),
    CM(0x0e, "gain", TByte),
    CMAO("fxm",
      CM(0x0f, "switch", TBool),
      CM(0x10, "color", TEnum),
      CM(0x11, "depth", TEnum),
    ),
    CM(0x12, "tempo_sync", TBool),
    CM(0x13, "coarse_tune", TByte),
    CM(0x14, "fine_tune", TByte),
    CM(0x15, "pan", TByte),
    CM(0x16, "random_pan_switch", TBool),
    CM(0x17, "alt_pan_switch", TBool),
    CM(0x18, "level", TByte),
  ),
  CMA( 0x19, "velocity", ranges),
]

let drum_tone_n = @[
  CM(0x00, "name", TName),
  CM(0x0c, "assign_single", TBool),
  CM(0x0d, "mute_group", TByte),
  CM(0x0e, "level", TByte),
  CM(0x0f, "coarse_tune", TByte),
  CM(0x10, "fine_tune", TByte),
  CM(0x11, "random_pitch_depth", TByte),
  CM(0x12, "pan", TByte),
  CM(0x13, "random_pan_depth", TByte),
  CM(0x14, "alt_pan_depth", TByte),
  CM(0x15, "env_mode", TByte),
  CM(0x16, "dry_send", TByte),
  CM(0x17, "chorus_send", TByte),
  CM(0x18, "reverb_send", TByte),
  CM(0x19, "chorus_send", TByte),
  CM(0x1a, "reverb_send", TByte),
  CM(0x1b, "output_assign", TByte),
  CM(0x1c, "bend_range", TByte),
  CMAO("rx",
    CM(0x1d, "expression", TBool),
    CM(0x1e, "hold_1", TBool),
    CM(0x1f, "pan_mode", TEnum),
  ),
  CMAO("wmt",
    CM(0x20, "velocity_control", TEnum),
    CMA(0x21, "1", drum_wmt_n),
    CMA(0x3e, "2", drum_wmt_n),
    CMA(0x5b, "3", drum_wmt_n),
    CMA(0x78, "4", drum_wmt_n),
  ),
  CMAO("pitch_env",
    CM(0x115, "depth", TByte),
    CM(0x116, "velocity_sens", TByte),
    CMAO("time",
      CM(0x117, "1_velocity_sens", TByte),
      CM(0x118, "4_velocity_sens", TByte),
      CM(0x119, "1", TByte),
      CM(0x11a, "2", TByte),
      CM(0x11b, "3", TByte),
      CM(0x11c, "4", TByte),
    ),
    CMAO("level",
      CM(0x11d, "0", TByte),
      CM(0x11e, "1", TByte),
      CM(0x11f, "2", TByte),
      CM(0x120, "3", TByte),
      CM(0x121, "4", TByte),
    ),
  ),
  CMAO("tvf",
    CM(0x122, "filter_type", TEnum),
    CMAO("cutoff",
      CM(0x123, "frequency", TByte),
      CM(0x124, "velocity_curve", TEnum),
      CM(0x125, "velocity_sens", TByte),
    ),
    CMAO("resonance",
      CM(0x126, "q", TByte),
      CM(0x127, "velocity_sens", TByte),
    ),
    CMAO("env",
      CM(0x128, "depth", TByte),
      CM(0x129, "velocity_curve_type", TEnum),
      CM(0x12a, "velocity_sens", TByte),
      CMAO("time",
        CM(0x12b, "1_velocity_sens", TByte),
        CM(0x12c, "4_velocity_sens", TByte),
        CM(0x12d, "1", TByte),
        CM(0x12e, "2", TByte),
        CM(0x12f, "3", TByte),
        CM(0x130, "4", TByte),
      ),
      CMAO("level",
        CM(0x131, "0", TByte),
        CM(0x132, "1", TByte),
        CM(0x133, "2", TByte),
        CM(0x134, "3", TByte),
        CM(0x135, "4", TByte),
      ),
    ),
  ),
  CMAO("tva",
    CMAO("level",
      CM(0x136, "velocity_curve", TByte),
      CM(0x137, "velocity_sens", TByte),
    ),
    CMAO("env",
      CMAO("time",
        CM(0x138, "1_velocity_sens", TByte),
        CM(0x139, "4_velocity_sens", TByte),
        CM(0x13a, "1", TByte),
        CM(0x13b, "2", TByte),
        CM(0x13c, "3", TByte),
        CM(0x13d, "4", TByte),
      ),
      CMAO("level",
        CM(0x13e, "1", TByte),
        CM(0x13f, "2", TByte),
        CM(0x140, "3", TByte),
      ),
    ),
  ),
  CM(0x141, "one_shot_mode", TBool),
  CM(0x142, "relative_level", TByte),
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
    CM(       0x0c, "category", TByte),
    CM(       0x0d, "reserved_1"),
    CM(       0x0e, "level", TByte),
    CM(       0x0f, "pan", TByte),
    CM(       0x10, "priority", TEnum),
    CM(       0x11, "coarse_tune", TByte),
    CM(       0x12, "fine_tune", TByte),
    CM(       0x13, "octave_shift", TByte),
    CM(       0x14, "stretch_tune_depth", TEnum),
    CM(       0x15, "analog_feel", TByte),
    CM(       0x16, "mono_poly", TBool),
    CM(       0x17, "legato_switch", TBool),
    CM(       0x18, "legato_retrigger", TBool),
    CMAO("portamento",
      CM(     0x19, "switch", TByte),
      CM(     0x1a, "mode", TEnum),
      CM(     0x1b, "type", TEnum),
      CM(     0x1c, "start", TEnum),
      CM(     0x1d, "time", TByte),
    ),
    CM(       0x1e, "reserved_2"),
    CM(       0x22, "cutoff_offset", TByte),
    CM(       0x23, "resonance_offset", TByte),
    CM(       0x24, "attack_offset", TByte),
    CM(       0x25, "release_offset", TByte),
    CM(       0x26, "velocity_offset", TByte),
    CM(       0x27, "output_assign", TEnum),
    CM(       0x28, "tmt_control_switch", TBool),
    CM(       0x29, "bend_range_up", TByte),
    CM(       0x2a, "bend_range_down", TByte),
    CMAO("matrix_control",
      CMA(    0x2b, "1", matrix_control ),
      CMA(    0x34, "2", matrix_control ),
      CMA(    0x3d, "3", matrix_control ),
      CMA(    0x46, "4", matrix_control ),
    ),
    CM(       0x4f, "modulation_switch", TBool),
    CMA(  0x000200, "mfx", mfx ),
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
    CM(       0x0c, "level", TByte),
    CM(       0x0d, "reserved"),
    CM(       0x11, "output_assign", TEnum),
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

let arpeggio_steps = TByte.repeat(32, 2)
let arpeggio_pattern = @[
  CM(0x0000, "original_note", TByte),
  CMAO("step", arpeggio_steps),
]
let arpeggio_patterns = arpeggio_pattern.repeat(16, 0x100)
let arpeggio = @[
  CM( 0x0000, "end_step", TByte),
  CM( 0x0002, "name", TName16),
  CM( 0x0012, "reserved"),
  CMA(0x1000, "pattern_note", arpeggio_patterns),
]

let pad = @[
  CM(0, "velocity", TByte),
  CM(2, "pattern_number", TNibblePair),
]
let pads = pad.repeat(8, 2)
let rhythm_group = @[
  CM(0x00, "name", TName16),
  CM(0x10, "bank_msb", TByte),
  CM(0x11, "bank_lsb", TByte),
  CM(0x12, "pc", TByte),
  CM(0x13, "reserved_1"),
  CMA(0x15, "pad", pads),
  CM(0x71, "reserved_2"),
  CM(0x72, "reserved_3"),
]

let vocal_effect = @[
  CM(0x00, "name", TName),
  CM(0x0c, "type", TEnum),
  CM(0x0d, "reserve_1"),
  CM(0x0e, "bank_msb", TByte),
  CM(0x0f, "bank_lsb", TByte),
  CM(0x10, "pc", TByte),
  CM(0x11, "level", TByte),
  CM(0x12, "pan", TByte),
  CM(0x13, "reserve_2"),
  CMAO("auto_pitch",
    CM(0x16, "type", TEnum),
    CM(0x17, "scale", TEnum),
    CM(0x18, "key", TEnum),
    CM(0x19, "note", TEnum),
    CM(0x1a, "gender", TEnum),
    CM(0x1b, "octave", TEnum),
    CM(0x1c, "balance", TByte),
  ),
  CMAO("vocoder",
    CM(0x1d, "envelope", TEnum),
    CM(0x1e, "mic_sens", TByte),
    CM(0x1f, "synth_level", TByte),
    CM(0x20, "mic_mix", TByte),
    CM(0x21, "mic_hpf", TEnum),
  ),
  CM(0x22, "part_level", TByte),
]

let voice_reserves = TByte.repeat(16, 1)
let midis = midi_n.repeat(16, 0x100)
let parts = part_n.repeat(16, 0x100)
let zones = zone_n.repeat(16, 0x100)
let performance_pattern = @[
  CMAO("common",
    CM(  0x00, "name", TName),
    CM(  0x0c, "solo", TBool),
    CM(  0x0d, "mfx1_channel", TByte),
    CM(  0x0e, "reserved_1"),
    CM(  0x0f, "reserved_2"),
    CMA( 0x10, "voice_reserve", voice_reserves),
    CM(  0x20, "reserved_3"),
    CM(  0x30, "mfx1_source", TEnum),
    CM(  0x31, "mfx2_source", TEnum),
    CM(  0x32, "mfx3_source", TEnum),
    CM(  0x33, "chorus_source", TEnum),
    CM(  0x34, "reverb_source", TEnum),
    CM(  0x35, "mfx2_channel", TEnum),
    CM(  0x36, "mfx3_channel", TEnum),
    CM(  0x37, "mfx_structure", TEnum),
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
    CM(  0x00, "reserved_1"),
    CM(  0x18, "arp_zone_number", TByte),
    CM(  0x19, "reserved_1"),
    CM(  0x54, "recommended_tempo", TNibblePair),
    CM(  0x56, "reserved_2"),
    CM(  0x59, "reserved_3"),
  ),
]

let setup = @[
  CM(     0x00, "sound_mode", TEnum),
  CMAO(         "performance",
    CM(   0x01, "bank_msb", TByte),
    CM(   0x02, "bank_lsb", TByte),
    CM(   0x03, "pc", TByte),
  ),
  CMAO(          "kbd_patch",
    CM(   0x04, "bank_msb", TByte),
    CM(   0x06, "bank_lsb", TByte),
    CM(   0x07, "pc", TByte),
  ),
  CMAO(         "rhy_patch",
    CM(   0x07, "bank_msb", TByte),
    CM(   0x08, "bank_lsb", TByte),
    CM(   0x09, "pc", TByte),
    CM(   0x0a, "mfx1_switch", TBool),
    CM(   0x0b, "mfx2_switch", TBool),
    CM(   0x0c, "mfx3_switch", TBool),
    CM(   0x0d, "chorus_switch", TBool),
    CM(   0x0e, "reverb_switch", TBool),
    CM(   0x0f, "reserved_1"),
    CM(   0x12, "transpose", TByte),
    CM(   0x13, "octave", TByte),
    CM(   0x14, "reserved_4"),
    CM(   0x15, "knob_select", TByte),
    CM(   0x16, "reserved_5"),
    CMAO(       "arpeggio",
      CM( 0x17, "grid", TEnum),
      CM( 0x18, "duration", TEnum),
      CM( 0x19, "switch", TBool),
      CM( 0x1a, "reserved_6"),
      CM( 0x1b, "style", TByte),
      CM( 0x1c, "motif", TEnum),
      CM( 0x1d, "octave", TByte),
      CM( 0x1e, "hold", TBool),
      CM( 0x1f, "accent", TByte),
      CM( 0x20, "velocity", TByte),
    ),
    CMAO(       "rhythm",
      CM( 0x21, "switch", TBool),
      CM( 0x22, "reserved_7"),
      CM( 0x23, "style", TNibblePair),
      CM( 0x25, "reserved_8"),
      CM( 0x26, "group", TByte),
      CM( 0x27, "accent", TByte),
      CM( 0x28, "velocity", TByte),
      CM( 0x29, "reserved_9"),
    ),
    CM(   0x33, "arpeggio_step", TByte),
  ),
]
let system = @[
  CMA(0x000000, "common",
    CMA(0x0000, "master",
      CM( 0x00, "tune", TNibbleQuad),
      CM( 0x04, "key_shift", TByte),
      CM( 0x05, "level", TByte),
    ),
    CM(   0x06, "scale_switch", TBool),
    CM(   0x07, "patch_remain", TBool),
    CM(   0x08, "mix_parallel", TBool),
    CM(   0x09, "channel", TBool),
    CM(   0x0a, "kbd_patch_channel", TBool),
    CM(   0x0b, "reserved_1", TBool),
    CMA(  0x0c, "scale", scale_map),
    CMAO(       "control_source",
      CM( 0x18, "1", TEnum),
      CM( 0x19, "2", TEnum),
      CM( 0x1a, "3", TEnum),
      CM( 0x1b, "4", TEnum),
    ),
    CMAO(       "rx",
      CM( 0x1c, "pc", TByte),
      CM( 0x1d, "bank", TByte),
    ),
  ),
  CMA(0x004000, "controller",
    CMAO(       "tx",
      CM( 0x00, "pc", TByte),
      CM( 0x01, "bank", TByte),
    ),
    CM(   0x02, "velocity", TByte),
    CM(   0x03, "velocity_curve", TEnum),
    CM(   0x04, "reserved_1"),
    CM(   0x05, "hold_polarity", TBool),
    CM(   0x06, "continuous_hold", TBool),
    CMAO(       "control_pedal",
      CM( 0x07, "assign", TEnum),
      CM( 0x08, "polarity", TEnum),
    ),
    CM(   0x09, "reserved_2"),
    CMAO(       "knob_assign",
      CM( 0x10, "1", TByte),
      CM( 0x11, "2", TByte),
      CM( 0x12, "3", TByte),
      CM( 0x13, "4", TByte),
    ),
    CM(   0x14, "reserved_2"),
    CM(   0x4d, "reserved_3"),
  ),
]

let performance_patterns = performance_pattern.repeat(128, 0x010000)
let performance_patches = patch.repeat(256, 0x10000)
let vocal_effects = vocal_effect.repeat(20, 0x100)
let drum_kits = drum_kit.repeat(8, 0x100000)
let juno_map = CMAO("",
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

proc traverse(mem: Mem, offset: JAddr, path: seq[string]) =
  let level = path.len
  var a = offset
  var hidden = mem.kind == TNone or mem.offset == NOFF
  if mem.offset != NOFF:
    a += mem.offset
  if not hidden:
    stdout.write "0x", a.toHex(8).toLower(), " "

  var desc = (path & mem.name).join(".")
  if desc.len > 0:
    desc = desc[1..^1]

  if not hidden:
    stdout.write desc
    stdout.write "\n"
  for area in mem.area:
    traverse(area, a, path & mem.name)


import std/terminal
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
  nt.path.add( nt.areas[^1][nt.selected].name )
  nt.coords.add( nt.selected )
  nt.cmdline = nt.path[1..^1].join(".")
  nt.pos = nt.cmdline.len() - nt.path[^1].len()
  #echo nt.coords
  nt.prompt = "0x" & nt.get_offset().toHex(8) & "> "

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

when isMainModule:
  let nt = Nteract(
    prompt: "0x00000000> ",
    cmdline: "",
    pos: 0,
    selected: 0,
    path: @["", "setup"],
    map: juno_map,
    areas: @[juno_map.area],
    coords: @[0],
  )
  #for area in nt.areas[^1]:
  #  echo area.name
  let input = nt.getUserInput()
  echo input
  #echo "hello"
  #traverse(juno_map, 0, @[])

