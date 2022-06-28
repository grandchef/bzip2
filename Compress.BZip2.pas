unit Compress.BZip2;

{
   ------------------------------------------------------------------
   This file is part of bzip2/libbzip2, a program and library for
   lossless, block-sorting data compression.

   bzip2/libbzip2 version 1.0.6 of 6 September 2010
   Copyright (C) 1996-2010 Julian Seward <jseward@bzip.org>

   Please read the WARNING, DISCLAIMER and PATENTS sections in the
   README file.

   This program is released under the terms of the license contained
   in the file LICENSE.
   ------------------------------------------------------------------

   Header conversion of bzlib.h
}

interface

uses
  System.Types, System.SysUtils, System.Classes, System.Zip;

{ DLL 使用時は'.'を削除 }
{.$DEFINE USE_DLL}

{$IFDEF USE_DLL}
const
  libbz2 = 'libbz2.dll';
{$ENDIF}

{$REGION 'bzlib.h translation'}
const
  BZ_RUN = 0;
  BZ_FLUSH = 1;
  BZ_FINISH = 2;

  BZ_OK = 0;
  BZ_RUN_OK = 1;
  BZ_FLUSH_OK = 2;
  BZ_FINISH_OK = 3;
  BZ_STREAM_END = 4;
  BZ_SEQUENCE_ERROR = (-1);
  BZ_PARAM_ERROR = (-2);
  BZ_MEM_ERROR = (-3);
  BZ_DATA_ERROR = (-4);
  BZ_DATA_ERROR_MAGIC = (-5);
  BZ_IO_ERROR = (-6);
  BZ_UNEXPECTED_EOF = (-7);
  BZ_OUTBUFF_FULL = (-8);
  BZ_CONFIG_ERROR = (-9);

type
  bzalloc_func = function(opaque: Pointer; Items, Size: Integer): Pointer; cdecl;
  bzfree_func = procedure(opaque, address: Pointer); cdecl;

  bz_stream = record
    next_in: PByte;
    avail_in: Cardinal;
    total_in_lo32: Cardinal;
    total_in_hi32: Cardinal;

    next_out: PByte;
    avail_out: Cardinal;
    total_out_lo32: Cardinal;
    total_out_hi32: Cardinal;

    state: Pointer;

    bzalloc: bzalloc_func;
    bzfree: bzfree_func;
    opaque: Pointer;
  end;


  (*-- Core (low-level) library functions --*)
  function BZ2_bzCompressInit(var strm: bz_stream; blockSize100k, verbosity,
    workFactor: Integer): Integer; stdcall; external {$IFDEF USE_DLL}libbz2{$ENDIF};
  function BZ2_bzCompress(var strm: bz_stream; action: Integer): Integer;
    stdcall; external {$IFDEF USE_DLL}libbz2{$ENDIF};
  function BZ2_bzCompressEnd(var strm: bz_stream): Integer; stdcall;
    external {$IFDEF USE_DLL}libbz2{$ENDIF};
  function BZ2_bzDecompressInit(var strm: bz_stream; verbosity, small: Integer): Integer;
    stdcall; external {$IFDEF USE_DLL}libbz2{$ENDIF};
  function BZ2_bzDecompress(var strm: bz_stream): Integer; stdcall; external {$IFDEF USE_DLL}libbz2{$ENDIF};
  function BZ2_bzDecompressEnd(var strm: bz_stream): Integer; stdcall; external {$IFDEF USE_DLL}libbz2{$ENDIF};

{$ENDREGION 'bzip2.h translation'}

type
  TBZAlloc = bzalloc_func;
  TBZFree = bzfree_func;

  TBZStreamRec = bz_stream;

  {** TCustomBZStream ********************************************************}

  TCustomBZStream = class(TStream)
  private
    FStream: TStream;
    FStreamStartPos: Int64;
    FStreamPos: Int64;
    FOnProgress: TNotifyEvent;
    FZStream: TBZStreamRec;
    FBuffer: array[Word] of Byte;
  protected
    constructor Create(stream: TStream);
    procedure DoProgress; dynamic;
    property OnProgress: TNotifyEvent read FOnProgress write FOnProgress;
  end;

  {** TZCompressionStream ***************************************************}

  TBZCompressionStream = class(TCustomBZStream)
  private
    function GetCompressionRate: Single;
  public
    constructor Create(dest: TStream); overload;
    destructor Destroy; override;
    function Read(var buffer; count: Longint): Longint; override;
    function Write(const buffer; count: Longint): Longint; override;
    function Seek(offset: Longint; origin: Word): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property CompressionRate: Single read GetCompressionRate;
    property OnProgress;
  end;

  {** TZDecompressionStream *************************************************}

  TBZDecompressionStream = class(TCustomBZStream)
  public
    constructor Create(source: TStream); overload;
    constructor Create(source: TStream; WindowBits: Integer); overload;
    destructor Destroy; override;
    function Read(var buffer; count: Longint): Longint; override;
    function Write(const buffer; count: Longint): Longint; override;
    function Seek(offset: Longint; origin: Word): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    property OnProgress;
  end;

  function bzAllocMem(AppData: Pointer; Items, Size: Integer): Pointer; cdecl;
  procedure bzFreeMem(AppData, Block: Pointer); cdecl;

type
  EBZError = class(Exception);
  EBZCompressionError = class(EBZError);
  EBZDecompressionError = class(EBZError);

const
  {** return code messages **************************************************}

  _bz_errmsg: array [0..14] of PAnsiChar = (
    'stream end',           // BZ_STREAM_END        (4)  //do not localize
    '',                     // BZ_FINISH_OK         (3)  //do not localize
    '',                     // BZ_FLUSH_OK          (2)  //do not localize
    '',                     // BZ_RUN_OK            (1)  //do not localize
    '',                     // BZ_OK                (0)  //do not localize
    'sequence error',       // BZ_SEQUENCE_ERROR    (-1) //do not localize
    'parameter error',      // BZ_PARAM_ERROR       (-2) //do not localize
    'insufficient memory',  // BZ_MEM_ERROR         (-3) //do not localize
    'data error',           // BZ_DATA_ERROR        (-4) //do not localize
    'magic bytes error',    // BZ_DATA_ERROR_MAGIC  (-5) //do not localize
    'io error',             // BZ_IO_ERROR          (-6) //do not localize
    'unexpected EOF',       // BZ_UNEXPECTED_EOF    (-7) //do not localize
    'out buffer full',      // BZ_OUTBUFF_FULL      (-8) //do not localize
    'config error',         // BZ_CONFIG_ERROR      (-9) //do not localize
    ''                                               //do not localize
    );
  SBZInvalid = 'Invalid BZStream operation!';

implementation

{$IFDEF MSWINDOWS}
{$IFNDEF USE_DLL}
  uses
    System.Win.crtl;

{$IF defined(WIN32)}
{$L Win32\bzlib.obj}
{$L Win32\blocksort.obj}
{$L Win32\huffman.obj}
{$L Win32\compress.obj}
{$L Win32\decompress.obj}
const
  _BZ2_crc32Table: Array[0..255] of UInt32 = (
   $00000000, $04c11db7, $09823b6e, $0d4326d9,
   $130476dc, $17c56b6b, $1a864db2, $1e475005,
   $2608edb8, $22c9f00f, $2f8ad6d6, $2b4bcb61,
   $350c9b64, $31cd86d3, $3c8ea00a, $384fbdbd,
   $4c11db70, $48d0c6c7, $4593e01e, $4152fda9,
   $5f15adac, $5bd4b01b, $569796c2, $52568b75,
   $6a1936c8, $6ed82b7f, $639b0da6, $675a1011,
   $791d4014, $7ddc5da3, $709f7b7a, $745e66cd,
   $9823b6e0, $9ce2ab57, $91a18d8e, $95609039,
   $8b27c03c, $8fe6dd8b, $82a5fb52, $8664e6e5,
   $be2b5b58, $baea46ef, $b7a96036, $b3687d81,
   $ad2f2d84, $a9ee3033, $a4ad16ea, $a06c0b5d,
   $d4326d90, $d0f37027, $ddb056fe, $d9714b49,
   $c7361b4c, $c3f706fb, $ceb42022, $ca753d95,
   $f23a8028, $f6fb9d9f, $fbb8bb46, $ff79a6f1,
   $e13ef6f4, $e5ffeb43, $e8bccd9a, $ec7dd02d,
   $34867077, $30476dc0, $3d044b19, $39c556ae,
   $278206ab, $23431b1c, $2e003dc5, $2ac12072,
   $128e9dcf, $164f8078, $1b0ca6a1, $1fcdbb16,
   $018aeb13, $054bf6a4, $0808d07d, $0cc9cdca,
   $7897ab07, $7c56b6b0, $71159069, $75d48dde,
   $6b93dddb, $6f52c06c, $6211e6b5, $66d0fb02,
   $5e9f46bf, $5a5e5b08, $571d7dd1, $53dc6066,
   $4d9b3063, $495a2dd4, $44190b0d, $40d816ba,
   $aca5c697, $a864db20, $a527fdf9, $a1e6e04e,
   $bfa1b04b, $bb60adfc, $b6238b25, $b2e29692,
   $8aad2b2f, $8e6c3698, $832f1041, $87ee0df6,
   $99a95df3, $9d684044, $902b669d, $94ea7b2a,
   $e0b41de7, $e4750050, $e9362689, $edf73b3e,
   $f3b06b3b, $f771768c, $fa325055, $fef34de2,
   $c6bcf05f, $c27dede8, $cf3ecb31, $cbffd686,
   $d5b88683, $d1799b34, $dc3abded, $d8fba05a,
   $690ce0ee, $6dcdfd59, $608edb80, $644fc637,
   $7a089632, $7ec98b85, $738aad5c, $774bb0eb,
   $4f040d56, $4bc510e1, $46863638, $42472b8f,
   $5c007b8a, $58c1663d, $558240e4, $51435d53,
   $251d3b9e, $21dc2629, $2c9f00f0, $285e1d47,
   $36194d42, $32d850f5, $3f9b762c, $3b5a6b9b,
   $0315d626, $07d4cb91, $0a97ed48, $0e56f0ff,
   $1011a0fa, $14d0bd4d, $19939b94, $1d528623,
   $f12f560e, $f5ee4bb9, $f8ad6d60, $fc6c70d7,
   $e22b20d2, $e6ea3d65, $eba91bbc, $ef68060b,
   $d727bbb6, $d3e6a601, $dea580d8, $da649d6f,
   $c423cd6a, $c0e2d0dd, $cda1f604, $c960ebb3,
   $bd3e8d7e, $b9ff90c9, $b4bcb610, $b07daba7,
   $ae3afba2, $aafbe615, $a7b8c0cc, $a379dd7b,
   $9b3660c6, $9ff77d71, $92b45ba8, $9675461f,
   $8832161a, $8cf30bad, $81b02d74, $857130c3,
   $5d8a9099, $594b8d2e, $5408abf7, $50c9b640,
   $4e8ee645, $4a4ffbf2, $470cdd2b, $43cdc09c,
   $7b827d21, $7f436096, $7200464f, $76c15bf8,
   $68860bfd, $6c47164a, $61043093, $65c52d24,
   $119b4be9, $155a565e, $18197087, $1cd86d30,
   $029f3d35, $065e2082, $0b1d065b, $0fdc1bec,
   $3793a651, $3352bbe6, $3e119d3f, $3ad08088,
   $2497d08d, $2056cd3a, $2d15ebe3, $29d4f654,
   $c5a92679, $c1683bce, $cc2b1d17, $c8ea00a0,
   $d6ad50a5, $d26c4d12, $df2f6bcb, $dbee767c,
   $e3a1cbc1, $e760d676, $ea23f0af, $eee2ed18,
   $f0a5bd1d, $f464a0aa, $f9278673, $fde69bc4,
   $89b8fd09, $8d79e0be, $803ac667, $84fbdbd0,
   $9abc8bd5, $9e7d9662, $933eb0bb, $97ffad0c,
   $afb010b1, $ab710d06, $a6322bdf, $a2f33668,
   $bcb4666d, $b8757bda, $b5365d03, $b1f740b4
  );

  _BZ2_rNums: Array[0..511] of Int32 = (
   619, 720, 127, 481, 931, 816, 813, 233, 566, 247,
   985, 724, 205, 454, 863, 491, 741, 242, 949, 214,
   733, 859, 335, 708, 621, 574, 73, 654, 730, 472,
   419, 436, 278, 496, 867, 210, 399, 680, 480, 51,
   878, 465, 811, 169, 869, 675, 611, 697, 867, 561,
   862, 687, 507, 283, 482, 129, 807, 591, 733, 623,
   150, 238, 59, 379, 684, 877, 625, 169, 643, 105,
   170, 607, 520, 932, 727, 476, 693, 425, 174, 647,
   73, 122, 335, 530, 442, 853, 695, 249, 445, 515,
   909, 545, 703, 919, 874, 474, 882, 500, 594, 612,
   641, 801, 220, 162, 819, 984, 589, 513, 495, 799,
   161, 604, 958, 533, 221, 400, 386, 867, 600, 782,
   382, 596, 414, 171, 516, 375, 682, 485, 911, 276,
   98, 553, 163, 354, 666, 933, 424, 341, 533, 870,
   227, 730, 475, 186, 263, 647, 537, 686, 600, 224,
   469, 68, 770, 919, 190, 373, 294, 822, 808, 206,
   184, 943, 795, 384, 383, 461, 404, 758, 839, 887,
   715, 67, 618, 276, 204, 918, 873, 777, 604, 560,
   951, 160, 578, 722, 79, 804, 96, 409, 713, 940,
   652, 934, 970, 447, 318, 353, 859, 672, 112, 785,
   645, 863, 803, 350, 139, 93, 354, 99, 820, 908,
   609, 772, 154, 274, 580, 184, 79, 626, 630, 742,
   653, 282, 762, 623, 680, 81, 927, 626, 789, 125,
   411, 521, 938, 300, 821, 78, 343, 175, 128, 250,
   170, 774, 972, 275, 999, 639, 495, 78, 352, 126,
   857, 956, 358, 619, 580, 124, 737, 594, 701, 612,
   669, 112, 134, 694, 363, 992, 809, 743, 168, 974,
   944, 375, 748, 52, 600, 747, 642, 182, 862, 81,
   344, 805, 988, 739, 511, 655, 814, 334, 249, 515,
   897, 955, 664, 981, 649, 113, 974, 459, 893, 228,
   433, 837, 553, 268, 926, 240, 102, 654, 459, 51,
   686, 754, 806, 760, 493, 403, 415, 394, 687, 700,
   946, 670, 656, 610, 738, 392, 760, 799, 887, 653,
   978, 321, 576, 617, 626, 502, 894, 679, 243, 440,
   680, 879, 194, 572, 640, 724, 926, 56, 204, 700,
   707, 151, 457, 449, 797, 195, 791, 558, 945, 679,
   297, 59, 87, 824, 713, 663, 412, 693, 342, 606,
   134, 108, 571, 364, 631, 212, 174, 643, 304, 329,
   343, 97, 430, 751, 497, 314, 983, 374, 822, 928,
   140, 206, 73, 263, 980, 736, 876, 478, 430, 305,
   170, 514, 364, 692, 829, 82, 855, 953, 676, 246,
   369, 970, 294, 750, 807, 827, 150, 790, 288, 923,
   804, 378, 215, 828, 592, 281, 565, 555, 710, 82,
   896, 831, 547, 261, 524, 462, 293, 465, 502, 56,
   661, 821, 976, 991, 658, 869, 905, 758, 745, 193,
   768, 550, 608, 933, 378, 286, 215, 979, 792, 961,
   61, 688, 793, 644, 986, 403, 106, 366, 905, 644,
   372, 567, 466, 434, 645, 210, 389, 550, 919, 135,
   780, 773, 635, 389, 707, 100, 626, 958, 165, 504,
   920, 176, 193, 713, 857, 265, 203, 50, 668, 108,
   645, 990, 626, 197, 510, 357, 358, 850, 858, 364,
   936, 638
  );

  function _BZ2_indexIntoF: integer; cdecl; external;
  procedure _BZ2_hbMakeCodeLengths; external;
  procedure _BZ2_hbAssignCodes; external;
  procedure _BZ2_hbCreateDecodeTables; external;
  procedure _BZ2_blockSort; external;
  procedure _bz_internal_error(errcode: Integer); cdecl;
  begin

  end;
{$ELSEIF defined(WIN64)}
{$L Win64\bzlib.obj}
{$L Win64\blocksort.obj}
{$L Win64\huffman.obj}
{$L Win64\compress.obj}
{$L Win64\decompress.obj}
const
  BZ2_crc32Table: Array[0..255] of UInt32 = (
   $00000000, $04c11db7, $09823b6e, $0d4326d9,
   $130476dc, $17c56b6b, $1a864db2, $1e475005,
   $2608edb8, $22c9f00f, $2f8ad6d6, $2b4bcb61,
   $350c9b64, $31cd86d3, $3c8ea00a, $384fbdbd,
   $4c11db70, $48d0c6c7, $4593e01e, $4152fda9,
   $5f15adac, $5bd4b01b, $569796c2, $52568b75,
   $6a1936c8, $6ed82b7f, $639b0da6, $675a1011,
   $791d4014, $7ddc5da3, $709f7b7a, $745e66cd,
   $9823b6e0, $9ce2ab57, $91a18d8e, $95609039,
   $8b27c03c, $8fe6dd8b, $82a5fb52, $8664e6e5,
   $be2b5b58, $baea46ef, $b7a96036, $b3687d81,
   $ad2f2d84, $a9ee3033, $a4ad16ea, $a06c0b5d,
   $d4326d90, $d0f37027, $ddb056fe, $d9714b49,
   $c7361b4c, $c3f706fb, $ceb42022, $ca753d95,
   $f23a8028, $f6fb9d9f, $fbb8bb46, $ff79a6f1,
   $e13ef6f4, $e5ffeb43, $e8bccd9a, $ec7dd02d,
   $34867077, $30476dc0, $3d044b19, $39c556ae,
   $278206ab, $23431b1c, $2e003dc5, $2ac12072,
   $128e9dcf, $164f8078, $1b0ca6a1, $1fcdbb16,
   $018aeb13, $054bf6a4, $0808d07d, $0cc9cdca,
   $7897ab07, $7c56b6b0, $71159069, $75d48dde,
   $6b93dddb, $6f52c06c, $6211e6b5, $66d0fb02,
   $5e9f46bf, $5a5e5b08, $571d7dd1, $53dc6066,
   $4d9b3063, $495a2dd4, $44190b0d, $40d816ba,
   $aca5c697, $a864db20, $a527fdf9, $a1e6e04e,
   $bfa1b04b, $bb60adfc, $b6238b25, $b2e29692,
   $8aad2b2f, $8e6c3698, $832f1041, $87ee0df6,
   $99a95df3, $9d684044, $902b669d, $94ea7b2a,
   $e0b41de7, $e4750050, $e9362689, $edf73b3e,
   $f3b06b3b, $f771768c, $fa325055, $fef34de2,
   $c6bcf05f, $c27dede8, $cf3ecb31, $cbffd686,
   $d5b88683, $d1799b34, $dc3abded, $d8fba05a,
   $690ce0ee, $6dcdfd59, $608edb80, $644fc637,
   $7a089632, $7ec98b85, $738aad5c, $774bb0eb,
   $4f040d56, $4bc510e1, $46863638, $42472b8f,
   $5c007b8a, $58c1663d, $558240e4, $51435d53,
   $251d3b9e, $21dc2629, $2c9f00f0, $285e1d47,
   $36194d42, $32d850f5, $3f9b762c, $3b5a6b9b,
   $0315d626, $07d4cb91, $0a97ed48, $0e56f0ff,
   $1011a0fa, $14d0bd4d, $19939b94, $1d528623,
   $f12f560e, $f5ee4bb9, $f8ad6d60, $fc6c70d7,
   $e22b20d2, $e6ea3d65, $eba91bbc, $ef68060b,
   $d727bbb6, $d3e6a601, $dea580d8, $da649d6f,
   $c423cd6a, $c0e2d0dd, $cda1f604, $c960ebb3,
   $bd3e8d7e, $b9ff90c9, $b4bcb610, $b07daba7,
   $ae3afba2, $aafbe615, $a7b8c0cc, $a379dd7b,
   $9b3660c6, $9ff77d71, $92b45ba8, $9675461f,
   $8832161a, $8cf30bad, $81b02d74, $857130c3,
   $5d8a9099, $594b8d2e, $5408abf7, $50c9b640,
   $4e8ee645, $4a4ffbf2, $470cdd2b, $43cdc09c,
   $7b827d21, $7f436096, $7200464f, $76c15bf8,
   $68860bfd, $6c47164a, $61043093, $65c52d24,
   $119b4be9, $155a565e, $18197087, $1cd86d30,
   $029f3d35, $065e2082, $0b1d065b, $0fdc1bec,
   $3793a651, $3352bbe6, $3e119d3f, $3ad08088,
   $2497d08d, $2056cd3a, $2d15ebe3, $29d4f654,
   $c5a92679, $c1683bce, $cc2b1d17, $c8ea00a0,
   $d6ad50a5, $d26c4d12, $df2f6bcb, $dbee767c,
   $e3a1cbc1, $e760d676, $ea23f0af, $eee2ed18,
   $f0a5bd1d, $f464a0aa, $f9278673, $fde69bc4,
   $89b8fd09, $8d79e0be, $803ac667, $84fbdbd0,
   $9abc8bd5, $9e7d9662, $933eb0bb, $97ffad0c,
   $afb010b1, $ab710d06, $a6322bdf, $a2f33668,
   $bcb4666d, $b8757bda, $b5365d03, $b1f740b4
  );

  BZ2_rNums: Array[0..511] of Int32 = (
   619, 720, 127, 481, 931, 816, 813, 233, 566, 247,
   985, 724, 205, 454, 863, 491, 741, 242, 949, 214,
   733, 859, 335, 708, 621, 574, 73, 654, 730, 472,
   419, 436, 278, 496, 867, 210, 399, 680, 480, 51,
   878, 465, 811, 169, 869, 675, 611, 697, 867, 561,
   862, 687, 507, 283, 482, 129, 807, 591, 733, 623,
   150, 238, 59, 379, 684, 877, 625, 169, 643, 105,
   170, 607, 520, 932, 727, 476, 693, 425, 174, 647,
   73, 122, 335, 530, 442, 853, 695, 249, 445, 515,
   909, 545, 703, 919, 874, 474, 882, 500, 594, 612,
   641, 801, 220, 162, 819, 984, 589, 513, 495, 799,
   161, 604, 958, 533, 221, 400, 386, 867, 600, 782,
   382, 596, 414, 171, 516, 375, 682, 485, 911, 276,
   98, 553, 163, 354, 666, 933, 424, 341, 533, 870,
   227, 730, 475, 186, 263, 647, 537, 686, 600, 224,
   469, 68, 770, 919, 190, 373, 294, 822, 808, 206,
   184, 943, 795, 384, 383, 461, 404, 758, 839, 887,
   715, 67, 618, 276, 204, 918, 873, 777, 604, 560,
   951, 160, 578, 722, 79, 804, 96, 409, 713, 940,
   652, 934, 970, 447, 318, 353, 859, 672, 112, 785,
   645, 863, 803, 350, 139, 93, 354, 99, 820, 908,
   609, 772, 154, 274, 580, 184, 79, 626, 630, 742,
   653, 282, 762, 623, 680, 81, 927, 626, 789, 125,
   411, 521, 938, 300, 821, 78, 343, 175, 128, 250,
   170, 774, 972, 275, 999, 639, 495, 78, 352, 126,
   857, 956, 358, 619, 580, 124, 737, 594, 701, 612,
   669, 112, 134, 694, 363, 992, 809, 743, 168, 974,
   944, 375, 748, 52, 600, 747, 642, 182, 862, 81,
   344, 805, 988, 739, 511, 655, 814, 334, 249, 515,
   897, 955, 664, 981, 649, 113, 974, 459, 893, 228,
   433, 837, 553, 268, 926, 240, 102, 654, 459, 51,
   686, 754, 806, 760, 493, 403, 415, 394, 687, 700,
   946, 670, 656, 610, 738, 392, 760, 799, 887, 653,
   978, 321, 576, 617, 626, 502, 894, 679, 243, 440,
   680, 879, 194, 572, 640, 724, 926, 56, 204, 700,
   707, 151, 457, 449, 797, 195, 791, 558, 945, 679,
   297, 59, 87, 824, 713, 663, 412, 693, 342, 606,
   134, 108, 571, 364, 631, 212, 174, 643, 304, 329,
   343, 97, 430, 751, 497, 314, 983, 374, 822, 928,
   140, 206, 73, 263, 980, 736, 876, 478, 430, 305,
   170, 514, 364, 692, 829, 82, 855, 953, 676, 246,
   369, 970, 294, 750, 807, 827, 150, 790, 288, 923,
   804, 378, 215, 828, 592, 281, 565, 555, 710, 82,
   896, 831, 547, 261, 524, 462, 293, 465, 502, 56,
   661, 821, 976, 991, 658, 869, 905, 758, 745, 193,
   768, 550, 608, 933, 378, 286, 215, 979, 792, 961,
   61, 688, 793, 644, 986, 403, 106, 366, 905, 644,
   372, 567, 466, 434, 645, 210, 389, 550, 919, 135,
   780, 773, 635, 389, 707, 100, 626, 958, 165, 504,
   920, 176, 193, 713, 857, 265, 203, 50, 668, 108,
   645, 990, 626, 197, 510, 357, 358, 850, 858, 364,
   936, 638
  );

  function BZ2_indexIntoF: integer; cdecl; external;
  procedure BZ2_hbMakeCodeLengths; external;
  procedure BZ2_hbAssignCodes; external;
  procedure BZ2_hbCreateDecodeTables; external;
  procedure BZ2_blockSort; external;
  procedure bz_internal_error(errcode: Integer); cdecl;
  begin

  end;

{$IFEND}

{$ENDIF}
{$ENDIF}

function BZCompressCheck(code: Integer): Integer;
begin
  result := code;

  if code < 0 then
  begin
    raise EBZCompressionError.Create(string(_bz_errmsg[4 - code]));
  end;
end;

function BZDecompressCheck(code: Integer): Integer;
begin
  Result := code;

  if code < 0 then
  begin
    raise EBZDecompressionError.Create(string(_bz_errmsg[4 - code]));
  end;
end;

function bzAllocMem(AppData: Pointer; Items, Size: Integer): Pointer;
begin
  Result := AllocMem(Items * Size);
end;

procedure bzFreeMem(AppData, Block: Pointer);
begin
  FreeMem(Block);
end;

{ TCustomBZStream }

constructor TCustomBZStream.Create(stream: TStream);
begin
  inherited Create;
  FStream := stream;
  FStreamStartPos := Stream.Position;
  FStreamPos := FStreamStartPos;
end;

procedure TCustomBZStream.DoProgress;
begin
  if Assigned(FOnProgress) then FOnProgress(Self);
end;

{ TBZCompressionStream }

constructor TBZCompressionStream.Create(dest: TStream);
begin
  inherited Create(dest);

  FZStream.opaque := Nil;
  FZStream.bzalloc := Nil;
  FZStream.bzfree := Nil;
  FZStream.next_out := @FBuffer;
  FZStream.avail_out := SizeOf(FBuffer);

  BZCompressCheck(BZ2_bzCompressInit(FZStream, 9, 0, 30));
end;

destructor TBZCompressionStream.Destroy;
begin
  FZStream.next_in := nil;
  FZStream.avail_in := 0;

  try
    if FStream.Position <> FStreamPos then FStream.Position := FStreamPos;

    while BZCompressCheck(BZ2_bzCompress(FZStream, BZ_FINISH)) <> BZ_STREAM_END do
    begin
      FStream.WriteBuffer(FBuffer, SizeOf(FBuffer) - FZStream.avail_out);

      FZStream.next_out := @FBuffer;
      FZStream.avail_out := SizeOf(FBuffer);
    end;

    if FZStream.avail_out < SizeOf(FBuffer) then
    begin
      FStream.WriteBuffer(FBuffer, SizeOf(FBuffer) - FZStream.avail_out);
    end;
  finally
    BZ2_bzCompressEnd(FZStream);
  end;

  inherited Destroy;
end;

function TBZCompressionStream.GetCompressionRate: Single;
var
  TotalIn: UInt64;
  TotalOut: UInt64;
begin
  TotalIn := (FZStream.total_in_hi32 Shl 32) + FZStream.total_in_lo32;
  TotalOut := (FZStream.total_out_hi32 Shl 32) + FZStream.total_out_lo32;

  if TotalIn = 0 then result := 0
  else result := (1.0 - (TotalOut / TotalIn)) * 100.0;
end;

function TBZCompressionStream.Read(var buffer; count: Integer): Longint;
begin
  raise EBZCompressionError.Create(SBZInvalid);
end;

function TBZCompressionStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
begin
  if (offset = 0) and (origin = soCurrent) then
  begin
    result := FZStream.total_in_hi32 Shl 32 + FZStream.total_in_lo32;
  end
  else raise EBZCompressionError.Create(SBZInvalid);
end;

function TBZCompressionStream.Seek(offset: Integer; origin: Word): Longint;
begin
  if (offset = 0) and (origin = soFromCurrent) then
  begin
    result := FZStream.total_in_hi32 Shl 32 + FZStream.total_in_lo32;
  end
  else raise EBZCompressionError.Create(SBZInvalid);
end;

function TBZCompressionStream.Write(const buffer; count: Integer): Longint;
begin
  FZStream.next_in := @buffer;
  FZStream.avail_in := count;

  if FStream.Position <> FStreamPos then FStream.Position := FStreamPos;

  while FZStream.avail_in > 0 do
  begin
    BZCompressCheck(BZ2_bzCompress(FZStream, BZ_RUN));

    if FZStream.avail_out = 0 then
    begin
      FStream.WriteBuffer(FBuffer, SizeOf(FBuffer));

      FZStream.next_out := @FBuffer;
      FZStream.avail_out := SizeOf(FBuffer);

      FStreamPos := FStream.Position;

      DoProgress;
    end;
  end;

  result := Count;
end;

{ TBZDecompressionStream }

constructor TBZDecompressionStream.Create(source: TStream);
begin
  Create(source, 15);
end;

constructor TBZDecompressionStream.Create(source: TStream; WindowBits: Integer);
begin
  inherited Create(source);
  FZStream.next_in := @FBuffer;
  FZStream.avail_in := 0;

  FZStream.opaque := Nil;
  FZStream.bzalloc := Nil;
  FZStream.bzfree := Nil;

  BZDecompressCheck(BZ2_bzDecompressInit(FZStream, 0, 0));
end;

destructor TBZDecompressionStream.Destroy;
begin
  BZ2_bzDecompressEnd(FZStream);
  inherited;
end;

function TBZDecompressionStream.Read(var buffer; count: Integer): Longint;
var
  zresult: Integer;
begin
  FZStream.next_out := @buffer;
  FZStream.avail_out := count;

  if FStream.Position <> FStreamPos then FStream.Position := FStreamPos;

  zresult := BZ_OK;

  while (FZStream.avail_out > 0) and (zresult <> BZ_STREAM_END) do
  begin
    if FZStream.avail_in = 0 then
    begin
      FZStream.avail_in := FStream.Read(FBuffer, SizeOf(FBuffer));

      if FZStream.avail_in = 0 then
      begin
        result := NativeUInt(count) - FZStream.avail_out;

        Exit;
      end;

      FZStream.next_in := @FBuffer;
      FStreamPos := FStream.Position;

      DoProgress;
    end;

    zresult := BZDecompressCheck(BZ2_bzDecompress(FZStream));
  end;

  if (zresult = BZ_STREAM_END) and (FZStream.avail_in > 0) then
  begin
    FStream.Position := FStream.Position - FZStream.avail_in;
    FStreamPos := FStream.Position;

    FZStream.avail_in := 0;
  end;

  result := NativeUInt(count) - FZStream.avail_out;
end;

function TBZDecompressionStream.Seek(const Offset: Int64;
  Origin: TSeekOrigin): Int64;
var
  buf: array[0..8191] of Char;
  i: Integer;
  vOffset: Int64;
begin
  vOffset := Offset;
  if (vOffset = 0) and (origin = soBeginning) then
  begin
    BZDecompressCheck(BZ2_bzDecompressEnd(FZStream));

    FZStream.next_in := @FBuffer;
    FZStream.avail_in := 0;
    FStream.Position := FStreamStartPos;
    FStreamPos := FStreamStartPos;

    BZDecompressCheck(BZ2_bzDecompressInit(FZStream, 0, 0));
  end
  else if ((vOffset >= 0) and (origin = soCurrent)) or
    (((NativeUInt(vOffset) - (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32) > 0) and (origin = soBeginning)) then
  begin
    if origin = soBeginning then Dec(vOffset, (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32);

    if vOffset > 0 then
    begin
      for i := 1 to vOffset div SizeOf(buf) do ReadBuffer(buf, SizeOf(buf));
      ReadBuffer(buf, vOffset mod SizeOf(buf));
    end;
  end
  else if (vOffset = 0) and (origin = soEnd) then
  begin
    while Read(buf, SizeOf(buf)) > 0 do ;
  end
  else raise EBZDecompressionError.Create(SBZInvalid);

  result := (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32;
end;

function TBZDecompressionStream.Seek(offset: Integer; origin: Word): Longint;
var
  buf: array[0..8191] of Char;
  i: Integer;
begin
  if (offset = 0) and (origin = soFromBeginning) then
  begin
    BZDecompressCheck(BZ2_bzDecompressEnd(FZStream));

    FZStream.next_in := @FBuffer;
    FZStream.avail_in := 0;
    FStream.Position := FStreamStartPos;
    FStreamPos := FStreamStartPos;

    BZDecompressCheck(BZ2_bzDecompressInit(FZStream, 0, 0));
  end
  else if ((offset >= 0) and (origin = soFromCurrent)) or
    (((NativeUInt(offset) - (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32) > 0) and (origin = soFromBeginning)) then
  begin
    if origin = soFromBeginning then Dec(offset, (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32);

    if offset > 0 then
    begin
      for i := 1 to offset div SizeOf(buf) do ReadBuffer(buf, SizeOf(buf));
      ReadBuffer(buf, offset mod SizeOf(buf));
    end;
  end
  else if (offset = 0) and (origin = soFromEnd) then
  begin
    while Read(buf, SizeOf(buf)) > 0 do ;
  end
  else raise EBZDecompressionError.Create(SBZInvalid);

  result := (FZStream.total_out_lo32 Shl 32) + FZStream.total_out_lo32;
end;

function TBZDecompressionStream.Write(const buffer; count: Integer): Longint;
begin
  raise EBZDecompressionError.Create(SBZInvalid);
end;


//initialization
//
//  TZipFile.RegisterCompressionHandler(zcBZIP2,
//    function(InStream: TStream; const ZipFile: TZipFile; const Item: TZipHeader): TStream
//    begin
//      Result := TBZCompressionStream.Create(InStream);
//    end,
//    function(InStream: TStream; const ZipFile: TZipFile; const Item: TZipHeader): TStream
//    begin
//      Result := TBZDecompressionStream.Create(InStream);
//    end);

end.

