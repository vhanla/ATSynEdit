unit ATStringProc_TextBuffer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  Dialogs,
  ATStringProc;

type
  TTextChangedEvent = procedure(Sender: TObject; Pos, Count, LineChange: integer) of object;

type
  { TATStringBuffer }

  TATStringBuffer = class
  private
    FList: array of integer;
    FListCapacity: integer;
    FListCount: integer;
    FLenEol: integer;
    FOnChange: TTextChangedEvent;
    procedure SetCount(AValue: integer);
  public
    FText: atString;
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Setup(const AText: atString; ALineLens: TList; ALenEol: integer);
    procedure SetupSlow(const AText: atString);
    procedure Clear;
    function CaretToStr(APnt: TPoint): integer;
    function StrToCaret(APos: integer): TPoint;
    function SubString(AFrom, ALen: integer): atString;
    function TextLength: integer;
    function LineIndex(N: integer): integer;
    function LineLength(N: integer): integer;
    function LineSpace(N: integer): integer;
    function OffsetToDistanceFromLineStart(APos: integer): integer;
    function OffsetToDistanceFromLineEnd(APos: integer): integer;
    function OffsetToOffsetOfLineStart(APos: integer): integer;
    function OffsetToOffsetOfLineEnd(APos: integer): integer;
    property Count: integer read FListCount;
    property OnChange: TTextChangedEvent read FOnChange write FOnChange;
  end;

implementation

{ TATStringBuffer }

procedure TATStringBuffer.SetCount(AValue: integer);
const
  cMinCap = 4*1024;
begin
  FListCount:= AValue;

  if AValue<0 then
    raise Exception.Create('StringBuffer Count<0');
  if AValue<=cMinCap then
    FListCapacity:= cMinCap
  else
  //first, round value to nearest N, which divides cMinCap
  //then, double the N
    FListCapacity:= AValue div cMinCap * (cMinCap*2);

  if Length(FList)<>FListCapacity then
    SetLength(FList, FListCapacity);
end;

constructor TATStringBuffer.Create;
begin
  FText:= '';
  FLenEol:= 1;
  SetLength(FList, 0);
  SetCount(0);
end;

destructor TATStringBuffer.Destroy;
begin
  SetLength(FList, 0);
  inherited;
end;

procedure TATStringBuffer.Setup(const AText: atString; ALineLens: TList;
  ALenEol: integer);
var
  Pos, NLen, i: integer;
begin
  FText:= AText;
  FLenEol:= ALenEol;

  SetCount(ALineLens.Count+1);
  Pos:= 0;
  FList[0]:= 0;
  for i:= 0 to ALineLens.Count-1 do
  begin
    NLen:= PtrInt(ALineLens[i]);
    Inc(Pos, NLen+FLenEol);
    FList[i+1]:= Pos;
  end;
end;

procedure TATStringBuffer.SetupSlow(const AText: atString);
var
  STextFinal: atString;
  L: TStringList;
  Lens: TList;
  i: integer;
begin
  if Trim(AText)='' then
  begin
    FText:= '';
    SetCount(0);
    Exit
  end;

  L:= TStringList.Create;
  Lens:= TList.Create;
  try
    L.TextLineBreakStyle:= tlbsLF;
    L.Text:= UTF8Encode(AText);
    STextFinal:= UTF8Decode(L.Text); //this converts eol to LF
    for i:= 0 to L.Count-1 do
      Lens.Add(Pointer(Length(UTF8Decode(L[i]))));
    Setup(STextFinal, Lens, 1);
  finally
    FreeAndNil(Lens);
    FreeAndNil(L);
  end;
end;

procedure TATStringBuffer.Clear;
begin
  FText:= '';
  SetCount(0);
end;

function TATStringBuffer.CaretToStr(APnt: TPoint): integer;
var
  Len: integer;
begin
  Result:= -1;
  if (APnt.Y<0) then Exit;
  if (APnt.X<0) then Exit;
  if (APnt.Y>=FListCount) then Exit;

  //handle caret pos after eol
  Len:= LineLength(APnt.Y);
  if APnt.X>Len then
    APnt.X:= Len;

  Result:= FList[APnt.Y]+APnt.X;
end;

function TATStringBuffer.StrToCaret(APos: integer): TPoint;
var
  a, b, m, dif: integer;
begin
  Result.Y:= -1;
  Result.X:= 0;
  if APos<=0 then
    begin Result.Y:= 0; Exit end;

  a:= 0;
  b:= FListCount-1;
  if b<0 then Exit;

  repeat
    dif:= FList[a]-APos;
    if dif=0 then begin m:= a; Break end;

    //middle, which is near b if not exact middle
    m:= (a+b+1) div 2;

    dif:= FList[m]-APos;
    if dif=0 then Break;

    if Abs(a-b)<=1 then begin m:= a; Break end;
    if dif>0 then b:= m else a:= m;
  until false;

  Result.Y:= m;
  Result.X:= APos-FList[Result.Y];
end;

function TATStringBuffer.SubString(AFrom, ALen: integer): atString;
begin
  Result:= Copy(FText, AFrom, ALen);
end;

function TATStringBuffer.TextLength: integer;
begin
  Result:= Length(FText);
end;

function TATStringBuffer.LineIndex(N: integer): integer;
begin
  if N<0 then Result:= 0
  else
  if N>=FListCount then Result:= TextLength-1
  else
    Result:= FList[N];
end;

function TATStringBuffer.LineLength(N: integer): integer;
begin
  if N<0 then Result:= 0
  else
  if N>=FListCount-1 then Result:= 0
  else
    Result:= FList[N+1]-FList[N]-FLenEol;
end;

function TATStringBuffer.LineSpace(N: integer): integer;
begin
  Result:= LineLength(N)+FLenEol;
end;

(*
//old code, seems it's slower so del'ed
function TATStringBuffer.OffsetToOffsetOfLineStart(APos: integer): integer;
var
  N: integer;
begin
  N:= StrToCaret(APos).Y;
  Result:= LineIndex(N);
end;

function TATStringBuffer.OffsetToOffsetOfLineEnd(APos: integer): integer;
var
  N: integer;
begin
  N:= StrToCaret(APos).Y;
  Result:= LineIndex(N)+LineLength(N);
end;
*)

function TATStringBuffer.OffsetToOffsetOfLineStart(APos: integer): integer;
begin
  Result:= APos-OffsetToDistanceFromLineStart(APos);
end;

function TATStringBuffer.OffsetToOffsetOfLineEnd(APos: integer): integer;
begin
  Result:= APos+OffsetToDistanceFromLineEnd(APos);
end;

function TATStringBuffer.OffsetToDistanceFromLineStart(APos: integer): integer;
const
  CharEol = #10;
var
  NPos, NLen: integer;
begin
  Result:= 0;
  NPos:= APos+1;
  NLen:= TextLength;
  while (NPos>1) and (NPos-1<=NLen) and (FText[NPos-1]<>CharEol) do
  begin
    Inc(Result);
    Dec(NPos);
  end;
end;

function TATStringBuffer.OffsetToDistanceFromLineEnd(APos: integer): integer;
const
  CharEol = #10;
var
  NLen, NPos: integer;
begin
  Result:= 0;
  NPos:= APos+1;
  NLen:= TextLength;
  while (NPos<NLen) and (FText[NPos+1]<>CharEol) do
  begin
    Inc(Result);
    Inc(NPos);
  end;
end;


end.

