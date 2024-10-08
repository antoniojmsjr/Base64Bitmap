{******************************************************************************}
{                                                                              }
{           Base64Lib.Parse.pas                                                }
{                                                                              }
{           Copyright (C) Ant�nio Jos� Medeiros Schneider J�nior               }
{                                                                              }
{           https://github.com/antoniojmsjr/Base64Lib                          }
{                                                                              }
{                                                                              }
{******************************************************************************}
{                                                                              }
{  Licensed under the Apache License, Version 2.0 (the "License");             }
{  you may not use this file except in compliance with the License.            }
{  You may obtain a copy of the License at                                     }
{                                                                              }
{      http://www.apache.org/licenses/LICENSE-2.0                              }
{                                                                              }
{  Unless required by applicable law or agreed to in writing, software         }
{  distributed under the License is distributed on an "AS IS" BASIS,           }
{  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    }
{  See the License for the specific language governing permissions and         }
{  limitations under the License.                                              }
{                                                                              }
{******************************************************************************}
unit Base64Lib.Parse;

interface

uses
  System.SysUtils, System.Classes, Base64Lib.Interfaces, System.Rtti,
  {$IF DEFINED(HAS_FMX)}FMX.Graphics{$ELSE}Vcl.Graphics{$ENDIF};

type
  TParseCustom = class(TInterfacedObject)
  private
    { private declarations }
    FStream: TBytesStream;
    function AsString: string;
    function AsStream: TStream;
    function AsBytes: TBytes;
    function Size: Int64;
    function MD5: string;
    procedure SaveToFile(const pFileName: string);
  protected
    { protected declarations }
  public
    { public declarations }
    constructor Create(const pBytes: TBytes); reintroduce; virtual;
    destructor Destroy; override;
  end;

  TEncodeParse = class(TParseCustom, IEncodeParse);
  TDecodeParse = class(TParseCustom, IDecodeParse)
  private
    { private declarations }
    {$IF DEFINED(HAS_FMX)}function AsBitmap: TBitmap;{$ENDIF}
    {$IF NOT DEFINED(HAS_FMX)}function AsPicture: TPicture;{$ENDIF}
  protected
    { protected declarations }
  public
    { public declarations }
  end;

implementation

uses
  {$IF CompilerVersion >= 30}System.Hash,{$ELSE}IdHashMessageDigest,{$ENDIF}
  {$IF NOT DEFINED(HAS_FMX)}Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg,{$ENDIF}
  IdGlobal, System.NetEncoding, Base64Lib.Types;

{$REGION 'TParseCustom'}
procedure TBytesToTIdBytes(const pInput: TBytes; var pOutput: TIdBytes);
var
  lLengthBytes: Integer;
begin
  lLengthBytes := Length(pInput);
  if (lLengthBytes = 0) then
  begin
    SetLength(pOutput, 0);
    Exit;
  end;

  SetLength(pOutput, lLengthBytes);
  move(Pointer(pInput)^, Pointer(pOutput)^, lLengthBytes);
end;

constructor TParseCustom.Create(const pBytes: TBytes);
begin
  FStream := TBytesStream.Create(pBytes);
  FStream.Position := 0;
end;

destructor TParseCustom.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TParseCustom.MD5: string;
var
{$IF CompilerVersion >= 30}
  lHashMD5: THashMD5;
{$ELSE}
  lIdHashMessageDigest5: TIdHashMessageDigest5;
  lIdBytes: TIdBytes;
{$ENDIF}
begin
{$IF CompilerVersion >= 30}
  lHashMD5 := THashMD5.Create;
  lHashMD5.Reset;
  lHashMD5.Update(FStream.Bytes);
  Result := lHashMD5.HashAsString;
{$ELSE}
  lIdHashMessageDigest5 := TIdHashMessageDigest5.Create;
  try
    TBytesToTIdBytes(FStream.Bytes, lIdBytes);
    Result := lIdHashMessageDigest5.HashBytesAsHex(lIdBytes);
  finally
    lIdHashMessageDigest5.Free;
  end;
{$ENDIF}
  Result := LowerCase(Result);
end;

procedure TParseCustom.SaveToFile(const pFileName: string);
begin
  try
    FStream.Position := 0;
    FStream.SaveToFile(pFileName);
  except
    on E: Exception do
    begin
      raise EBase64Lib.Build
        .Title('Failed to save the file.')
        .Error(E.Message)
        .Hint('Check the error message.')
        .ClassName(Self.ClassName);
    end;
  end;
end;

function TParseCustom.Size: Int64;
begin
  FStream.Position := 0;
  Result := FStream.Size;
end;

function TParseCustom.AsBytes: TBytes;
begin
  FStream.Position := 0;
  Result := FStream.Bytes;
end;

function TParseCustom.AsStream: TStream;
begin
  FStream.Position := 0;
  Result := TBytesStream.Create(FStream.Bytes);
  Result.Position := 0;
end;

function TParseCustom.AsString: string;
begin
  Result := TEncoding.UTF8.GetString(FStream.Bytes);
end;
{$ENDREGION}

{$REGION 'TDecodeParse'}

{$IF DEFINED(HAS_FMX)} // FMX
function TDecodeParse.AsBitmap: TBitmap;
begin
  FStream.Position := 0;
  Result := TBitmap.CreateFromStream(FStream);
end;
{$ENDIF}

{$IF NOT DEFINED(HAS_FMX)} // VCL
function TDecodeParse.AsPicture: TPicture;
var
  lWICImage: TWICImage; //https://docwiki.embarcadero.com/Libraries/Athens/en/Vcl.Graphics.TWICImage
begin
  FStream.Position := 0;
  Result := TPicture.Create;

  lWICImage := TWICImage.Create;
  try
    lWICImage.LoadFromStream(FStream);
    Result.Assign(lWICImage);
  finally
    lWICImage.Free;
  end;
end;
{$ENDIF}

{$ENDREGION}

end.
