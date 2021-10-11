{$R-}
unit demoLog;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, Menus, WSocket;

type
  TLog = class(TForm)
    LogWnd: TRichEdit;
    PopupMenu: TPopupMenu;
    Copy1: TMenuItem;
    Clear1: TMenuItem;
    Refresh1: TMenuItem;
    LineMode1: TMenuItem;
    Debugstring1: TMenuItem;
    Wordwrap1: TMenuItem;
    WSocket1: TWSocket;
    procedure FormCreate(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure Clear1Click(Sender: TObject);
    procedure Refresh1Click(Sender: TObject);
    procedure LineMode1Click(Sender: TObject);
    procedure Debugstring1Click(Sender: TObject);
    procedure Wordwrap1Click(Sender: TObject);
  private
    function DebugStr(Source: pointer; Len: integer): string;
  public
    TextColor: TColor;
    Header:    string;
    procedure Add(const ToLog: string);
  end;

var
  Log: TLog;

implementation

uses demoMain;

{$R *.DFM}

//------------------------------------------------------------------------------
function HexByte(c: byte): word;
asm
      mov ah, al     // save byte in ah
      shr al, 4      // filter high order nibble
      add al, 30h    // 0 -> 30h, 1 -> 31h, enz
      cmp al, 39h    // check if A..F
      jbe @1
      add al, 7      // A..F
@1:   mov dl, al     // zet result efkes weg
      mov al, ah     // pak byte opniew
      and al, 0Fh    // filter low order nibble
      add al, 30h    // 0 -> 30h, 1 -> 31h, enz
      cmp al, 39h    // check if A..F
      jbe @2
      add al, 7      // A..F
@2:   mov ah, al
      mov al, dl
end;

//------------------------------------------------------------------------------
function TLog.DebugStr(Source: pointer; Len: integer): string;
var
   p, Debug: PChar;
   Ascii: array[0..16] of char;
   Hex:   array[0..3] of char;
   nHex:  word absolute Hex;
   addr:  word;
   n, j, i: integer;
begin
   if len = 0 then
   begin
      result := '';
      exit;
   end;

   if (len and $F) = 0 then
        SetLength(result, len div 16 * 71 + 1)
   else SetLength(result, len div 16 * 71 + len mod 16 + 56);

   FillChar(Ascii, sizeof(Ascii), 0);
   Hex[3] := #0;
   p := Source;
   j := 0;
   addr := 0;
   Debug := @result[1];
   Debug := StrECopy(StrECopy(Debug, PChar(IntToHex(addr, 4))), ' ');
   inc(addr, 16);

   for n := 0 to Len - 1 do
   begin
      nHex := HexByte(byte(p[n]));

      if p[n] < ' ' then ascii[j] := '.'
      else ascii[j] := char(p[n]);

      if j = 7 then Hex[2] := '-'
      else Hex[2] := ' ';
      Debug := StrECopy(Debug, Hex);

      if j = 15 then
      begin
         Debug := StrECopy(StrECopy(Debug, Ascii), #13#10);
         FillChar(Ascii, sizeof(Ascii), 0);
         j := 0;
         if n < len - 1 then
         begin
            Hex[2] := #0;
            nHex   := HexByte(addr shr 8);
            Debug  := StrECopy(Debug, Hex);
            nHex   := HexByte(addr);
            Debug  := StrECopy(StrECopy(Debug, Hex), ' ');
            inc(addr, 16);
         end;
      end
      else inc(j);
   end;

   if j > 0 then
   begin
      i := 48 - j * 3;
      for n := 0 to i - 1 do Debug[n] := ' ';
      Debug := Debug + i;
      StrECopy(StrECopy(Debug, Ascii), #13#10);
   end;

   SetLength(result, length(result) - 1); // remove terminating null
end;

//------------------------------------------------------------------------------
procedure TLog.FormCreate(Sender: TObject);
begin
   LogWnd.Clear;
   Header := '';
   TextColor := clBlack;
end;

//------------------------------------------------------------------------------
function RemoveLowChar(const Source: string): string;
var n: integer;
begin
   Setlength(Result, length(Source));
   for n := 1 to length(Source) do
      if Source[n] < #10 then Result[n] := '.'
      else Result[n] := Source[n];
end;

//------------------------------------------------------------------------------
procedure TLog.Add(const ToLog: string);
var OrgPos: integer;
begin
   if not visible then show;

   { Start adding lines in right color, but dont scroll to the end
     whilst adding lines, even if it has focus.
     Only if Refresh is checked then scroll to end }

   with LogWnd do
   begin
      OrgPos := SelStart;
      Lines.BeginUpdate;

      try
         SelStart := GetTextLen;
         SelAttributes.Color := TextColor;

         if (Lines.Count > 0) and (Lines[Lines.Count - 1] <> '') then Lines.Add('');
         Lines.Add(DateTimeToStr(Now) + ' ' + Header);

         if not DebugString1.Checked then Lines.Add(RemoveLowChar(ToLog))
         else Lines.Add(DebugStr(@ToLog[1], length(ToLog)));

         SelStart := OrgPos;
         Perform(EM_SCROLLCARET, 0, 0);  // I think this is not needed in Delphi 5
      finally
         Lines.EndUpdate;
      end;

      if Refresh1.Checked then
      begin
         SelStart := GetTextLen;
         Perform(EM_SCROLLCARET, 0, 0);  // I think this is not needed in Delphi 5
      end;
   end;
end;

//------------------------------------------------------------------------------
procedure TLog.Copy1Click(Sender: TObject);
begin
   with LogWnd do
   begin
      SelectAll;
      CopyToClipboard;
      SelLength := 0;
   end;
end;

//------------------------------------------------------------------------------
procedure TLog.Clear1Click(Sender: TObject);
begin
   LogWnd.Clear;
end;

//------------------------------------------------------------------------------
procedure TLog.Refresh1Click(Sender: TObject);
begin
   with Sender as TMenuItem do Checked := not Checked;
end;

//------------------------------------------------------------------------------
procedure TLog.LineMode1Click(Sender: TObject);
var
 n: integer;
begin
   with Sender as TMenuItem do
   begin
      Checked := not Checked;
      with Main.HTTPProxy.SocketServer do
         for n := 0 to ClientCount - 1 do
            with Client[n] as TSpyProxyClient do
            begin
               LineMode := Checked;
               RemoteSocket.LineMode := Checked;
            end;
   end;
end;

procedure TLog.Debugstring1Click(Sender: TObject);
begin
 with Sender as TMenuItem do
  Checked:=not Checked;
end;

procedure TLog.Wordwrap1Click(Sender: TObject);
begin
 with Sender as TMenuItem do
  begin
   Checked := not Checked;
   LogWnd.WordWrap := Checked;
  end;
end;

end.
