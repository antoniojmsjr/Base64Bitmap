unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls, Data.DB,
  Vcl.Grids, Vcl.DBGrids, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Param, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Phys.Intf,
  FireDAC.DApt.Intf, FireDAC.Comp.DataSet, FireDAC.Comp.Client, Horse, SyncObjs,
  Vcl.ExtDlgs;

type
  TfrmMain = class(TForm)
    pnlHeader: TPanel;
    lblHeader: TLabel;
    pnlServerTools: TPanel;
    lblServerPort: TLabel;
    edtServerPort: TEdit;
    btnServerStart: TButton;
    btnServerStop: TButton;
    gbRequest: TGroupBox;
    dbgRequest: TDBGrid;
    mtRequest: TFDMemTable;
    mtRequestID: TIntegerField;
    mtRequestBASE64: TBlobField;
    dsRequest: TDataSource;
    mtRequestMESSAGE: TStringField;
    pnlBottom: TPanel;
    imgBitmap: TImage;
    mmoBase64: TMemo;
    lblSiteBase64Guru: TLinkLabel;
    lblTestePingPong: TLinkLabel;
    lblViewBase64Browser: TLinkLabel;
    lblViewBitmapBrowser: TLinkLabel;
    mtRequestCONTENT_TYPE: TStringField;
    mtRequestTYPE_BITMAP: TStringField;
    procedure FormCreate(Sender: TObject);
    procedure mtRequestCalcFields(DataSet: TDataSet);
    procedure dbgRequestDblClick(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure btnServerStopClick(Sender: TObject);
    procedure btnServerStartClick(Sender: TObject);
    procedure lblSiteBase64GuruLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure lblTestePingPongLinkClick(Sender: TObject; const Link: string;
      LinkType: TSysLinkType);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure lblViewBase64BrowserLinkClick(Sender: TObject;
      const Link: string; LinkType: TSysLinkType);
  private
    { Private declarations }
    FLock: TCriticalSection;
    procedure GetBase64(pReq: THorseRequest; pRes: THorseResponse);
    procedure GetBitmap(pReq: THorseRequest; pRes: THorseResponse);
    procedure PostBitmap(pReq: THorseRequest; pRes: THorseResponse);
    procedure OpenLink(const pLink: string);
    procedure Routers;
    procedure StatusServer;
    function SaveRequest(const pContentType: string; const pBase64: TStream): Integer;
    function LocateBase64(const pID: Integer; out poContentType: string): string;
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  System.Types, Winapi.ShellApi, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage,
  Vcl.Imaging.GIFImg, System.NetEncoding, Horse.Commons, Base64Lib, Base64Lib.Utils,
  Web.HTTPApp, System.Math;

{$R *.dfm}

{ TfrmMain }

procedure TfrmMain.FormCreate(Sender: TObject);
var
  lRect: TRectF;
begin
  lblSiteBase64Guru.Caption := '<a href="https://base64.guru/converter/decode/image">www.base64.guru</a>';

  lRect := TRectF.Create(Screen.WorkAreaRect.TopLeft, Screen.WorkAreaRect.Width,
                         Screen.WorkAreaRect.Height);
  SetBounds(Round(lRect.Left + (lRect.Width - Width) / 2),
            0,
            Width,
            Screen.WorkAreaRect.Height);

  FLock := TCriticalSection.Create;
  StatusServer;
  Routers;
end;

procedure TfrmMain.FormResize(Sender: TObject);
begin
  if (Self.Width < 650) then
  begin
    Self.Width := 650;
    Abort;
  end;
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if THorse.IsRunning then
    THorse.StopListen;
  FLock.Free;
end;

procedure GetAllDataAsStream(pRequest: TWebRequest; pStream: TStream);
var
  lContentLength: Integer;
  lBufferRead: Integer;
  lBuffer: array[0..1023] of Byte;
begin
  lContentLength := pRequest.ContentLength;
  while (lContentLength > 0) do
  begin
    lBufferRead := pRequest.ReadClient(lBuffer[0], Min(lContentLength, SizeOf(lBuffer)));
    if (lBufferRead < 1) then
      Break;
    pStream.WriteBuffer(lBuffer[0], lBufferRead);
    Dec(lContentLength, lBufferRead);
  end;
  pStream.Position:= 0;
end;

procedure TfrmMain.btnServerStartClick(Sender: TObject);
begin
  THorse.Listen(StrToInt(edtServerPort.Text));
  lblTestePingPong.Caption := Format('<a href="http://localhost:%s/ping">Test Servidor</a>', [edtServerPort.Text]);
  StatusServer;
  mtRequest.CreateDataSet;
end;

procedure TfrmMain.btnServerStopClick(Sender: TObject);
begin
  if THorse.IsRunning then
    THorse.StopListen;
  StatusServer;
  mtRequest.Close;
end;

procedure TfrmMain.dbgRequestDblClick(Sender: TObject);
var
  lBase64: string;
  lID: Integer;
  lPicture: TPicture;
begin
  lID := mtRequest.FieldByName('ID').AsInteger;
  lBase64 := mtRequest.FieldByName('BASE64').AsString;

  if (lBase64 = '') then
    Exit;

  lblViewBase64Browser.Caption := Format('<a href="http://localhost:%s/base64/%d">GET Base64: %d</a>', [edtServerPort.Text, lID, lID]);
  lblViewBase64Browser.Visible := True;
  lblViewBitmapBrowser.Caption := Format('<a href="http://localhost:%s/bitmap/%d">GET Bitmap: %d</a>', [edtServerPort.Text, lID, lID]);
  lblViewBitmapBrowser.Visible := True;

  //VIEW IMAGE
  lPicture := nil;
  try
    // DECODE
    lPicture := TBase64Lib
      .Build
        .Decode
          .Text(lBase64).AsPicture;

    imgBitmap.Picture.Assign(nil);
    imgBitmap.Picture.Assign(lPicture);
  finally
    lPicture.Free;
  end;

  // VIEW BASE64
  TThread.Synchronize(nil, procedure
  begin
    mmoBase64.Clear;
    mmoBase64.Text := 'Wait...';
    Application.ProcessMessages;

    mmoBase64.Clear;
    mmoBase64.Lines.Add(lBase64);
    Application.ProcessMessages;
  end);
end;

function TfrmMain.LocateBase64(const pID: Integer; out poContentType: string): string;
begin
  Result := EmptyStr;
  poContentType := EmptyStr;

  FLock.Enter;
  try
    if not mtRequest.FindKey([pID]) then
      Exit;

    Result := mtRequest.FieldByName('BASE64').AsString;
    poContentType := mtRequest.FieldByName('CONTENT_TYPE').AsString;
  finally
    FLock.Leave;
  end;
end;

procedure TfrmMain.GetBase64(pReq: THorseRequest; pRes: THorseResponse);
var
  lID: Integer;
  lBase64: string;
  lContentType: string;
begin
  lID := pReq.Params.Field('id').AsInteger;

  TTHread.Synchronize(nil, procedure
  begin
    lBase64 := LocateBase64(lID, lContentType);
  end);

  if (lBase64 <> EmptyStr) then
    pRes.Send(lBase64)
  else
    pRes.Send(Format('Code [%d] not found.', [lID])).Status(THTTPStatus.NotFound);
end;

procedure TfrmMain.GetBitmap(pReq: THorseRequest; pRes: THorseResponse);
var
  lID: Integer;
  lBase64: string;
  lContentType: string;
  lBitmapStream: TStream;
begin
  lID := pReq.Params.Field('id').AsInteger;

  TTHread.Synchronize(nil, procedure
  begin
    lBase64 := LocateBase64(lID, lContentType);
  end);

  if (lBase64 <> EmptyStr) then
  begin
    lBitmapStream := nil;
    try
      // DECODE
      lBitmapStream := TBase64Lib
      .Build
        .Decode
          .Text(lBase64).AsStream;

      pRes.SendFile(lBitmapStream, '', lContentType);
    finally
      lBitmapStream.Free;
    end;
  end
  else
    pRes.Send(Format('Code [%d] not found.', [lID])).Status(THTTPStatus.NotFound);
end;

procedure TfrmMain.lblSiteBase64GuruLinkClick(Sender: TObject;
  const Link: string; LinkType: TSysLinkType);
begin
  OpenLink(Link);
end;

procedure TfrmMain.lblTestePingPongLinkClick(Sender: TObject;
  const Link: string; LinkType: TSysLinkType);
begin
  OpenLink(Link);
end;

procedure TfrmMain.lblViewBase64BrowserLinkClick(Sender: TObject;
  const Link: string; LinkType: TSysLinkType);
begin
  OpenLink(Link);
end;

procedure TfrmMain.mtRequestCalcFields(DataSet: TDataSet);
begin
  DataSet.FieldByName('MESSAGE').AsString := 'Double click to decode Base64 to Bitmap.';
end;

procedure TfrmMain.OpenLink(const pLink: string);
begin
  ShellExecute(0, 'OPEN', PChar(pLink), nil, nil, SW_SHOWNORMAL);
end;

procedure TfrmMain.PostBitmap(pReq: THorseRequest; pRes: THorseResponse);
var
  lBytes: TBytes;
  lBitmapStream: TBytesStream;
  lBase64Stream: TStream;
  lID: Integer;
begin
  lBase64Stream := nil;

  // IMAGE RECEIVED
  {$IF CompilerVersion >= 30}
  lBitmapStream := TBytesStream.Create(pReq.RawWebRequest.RawContent);
  {$ELSE}
  Setlength(lBytes, pReq.RawWebRequest.ContentLength);
  lBitmapStream := TBytesStream.Create(lBytes);
  GetAllDataAsStream(pReq.RawWebRequest, lBitmapStream);
  {$ENDIF}

  try
    // IMAGE TO BASE64
    lBitmapStream.Position := 0;

    // ENCODE
    lBase64Stream := TBase64Lib
      .Build
        .Encode
          .Stream(lBitmapStream).AsStream;

    try
      FLock.Enter;
      // SAVE IMAGE IN BASE64
      TThread.Synchronize(nil, procedure
      begin
        lID := SaveRequest(pReq.RawWebRequest.ContentType, lBase64Stream);
      end);
    finally
      FLock.Leave;
    end;

    pRes.Send(IntToStr(lID)).Status(THTTPStatus.Created);
  finally
    lBase64Stream.Free;
  end;
end;

function TfrmMain.SaveRequest(const pContentType: string; const pBase64: TStream): Integer;
var
  lID: Integer;
begin
  Randomize;
  lID := Random(99999);

  mtRequest.Append;
  mtRequest.FieldByName('ID').AsInteger := lID;
  mtRequest.FieldByName('CONTENT_TYPE').AsString := pContentType;

  pBase64.Position := 0;
  TBlobField(mtRequest.FieldByName('BASE64')).LoadFromStream(pBase64);

  mtRequest.FieldByName('TYPE_BITMAP').AsString :=
    TUtilsImage.DetectImage(mtRequest.FieldByName('BASE64').AsString).AsString;

  mtRequest.Post;

  Result := lID;
end;

procedure TfrmMain.StatusServer;
begin
  btnServerStop.Enabled := THorse.IsRunning;
  btnServerStart.Enabled := not THorse.IsRunning;
  edtServerPort.Enabled := not THorse.IsRunning;
  lblTestePingPong.Visible := THorse.IsRunning;
end;

procedure TfrmMain.Routers;
begin
  THorse.Get('ping',
    procedure(pReq: THorseRequest; pRes: THorseResponse)
    begin
      pRes.Send('pong');
    end);

  THorse.Get('base64/:id', GetBase64);
  THorse.Get('bitmap/:id', GetBitmap);
  THorse.Post('bitmap/', PostBitmap);
end;

end.
