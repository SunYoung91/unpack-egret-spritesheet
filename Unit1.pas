unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,Winapi.ShellAPI,QJson,Vcl.Imaging.pngimage;

type
  TForm1 = class(TForm)
    mmo_log: TMemo;
    lbl1: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure WmDropFiles(var Msg: TMessage); message WM_DROPFILES;
    procedure DoUnPack(FileName:String);
  end;


  TChunkIHDRHelper = class helper for TChunkIHDR
  public
    function GetPerPixelByteSize():Integer;

  end;


var
  Form1: TForm1;

implementation

{$R *.dfm}

{ TForm1 }

procedure TForm1.DoUnPack(FileName: String);
var
  jsonFileName:String;
  Json,frames,node : TQJson;
  i:Integer;
  Png : TPngImage;
  tempPng : TPngImage;
  W,H,X,Y:Integer;
  targetPath : String;
  AX,AY:Integer;
  pPngAlphaLine:PByte;
  pTempPngAlphaLine:PByte;
  PerPixelSize : Integer;
  ALineLen : Integer;
begin
  mmo_log.Lines.Add('开始处理:' + FileName);
  FileName := ChangeFileExt(FileName,'.png');
  if not FileExists(FileName) then
  begin
    mmo_log.Lines.Add('图集文件不存在:' + FileName);
    Exit;
  end;

  jsonFileName := ChangeFileExt(FileName,'.json');
  if not FileExists(jsonFileName) then
  begin
    mmo_log.Lines.Add('json描述文件不存在:' + jsonFileName);
    Exit;
  end;

  Json := TQJson.Create;
  json.LoadFromFile(jsonFileName);
  frames := Json.ItemByPath('.frames');

  if frames = nil then
  begin
    mmo_log.Lines.Add('无法找到 frames 子节点');
    Exit;
  end;

  targetPath := ChangeFileExt(FileName,'') + '_unpacked';

  if not DirectoryExists(targetPath) then
  begin
    if not ForceDirectories(targetPath) then
    begin
      raise Exception.Create('无法创建目录:' + targetPath );
    end;
  end;

  Png := TPngImage.Create;
  Png.LoadFromFile(FileName);

//  for i := 0 to Png.Chunks.Count - 1 do
//  begin
//    mmo_log.Lines.Add('Chk: Png - ' + I .ToString + ':' + Png.Chunks.Item[i].Name);
//  end;

  PerPixelSize := Png.Header.GetPerPixelByteSize();

  for i := 0 to frames.Count - 1 do
  begin
    node :=  frames.Items[i];

    W := Node.IntByName('w',0);
    h := Node.IntByName('h',0);
    x := Node.IntByName('x',0);
    y := Node.IntByName('y',0);

    if (W <=0) or (H <=0) then
    begin
      mmo_log.Lines.Add('跳过 宽度高度 为0的图片:' + Node.Name);
      Continue;
    end;

    tempPng := TPngImage.Create;
    tempPng.CreateBlank(Png.Header.ColorType,png.header.BitDepth,w,h);

    ALineLen := TempPng.Width * PerPixelSize;

    //先直接拷贝像素数据
    for AY := 0 to tempPng.Height - 1 do
    begin
      pPngAlphaLine := PByte(Png.Scanline[AY + Y]);
      pTempPngAlphaLine := PByte(tempPng.Scanline[AY]);
      Inc(pPngAlphaLine,X * PerPixelSize);
      Move(pPngAlphaLine^,pTempPngAlphaLine^,ALineLen);
    end;


    //然后处理透明通道的数据
    if Png.Header.ColorType = COLOR_PALETTE  then
    begin
      tempPng.Palette := Png.Palette;

      //如果是调色板模式那么直接拷贝透明通道数据
      if Png.TransparencyMode <> ptmNone then
      begin
        tempPng.CreateAlpha();
        tempPng.Chunks.ItemFromClass(TChunktRNS).Assign(Png.Chunks.ItemFromClass(TChunktRNS));
      end;
    end else
    begin
      if Png.TransparencyMode <> ptmNone then
      begin
        tempPng.CreateAlpha();
        for AY := 0 to tempPng.Height - 1 do
        begin
          pPngAlphaLine := PByte(Png.AlphaScanline[AY + Y]);
          pTempPngAlphaLine := PByte(tempPng.AlphaScanline[AY]);
          Inc(pPngAlphaLine,X);
          Move(pPngAlphaLine^,pTempPngAlphaLine^,tempPng.Width);
        end;
      end;
    end;

//    for AX := 0 to tempPng.Chunks.Count - 1 do
//    begin
//      mmo_log.Lines.Add('Chk: TempPng - ' + AX .ToString + ':' + tempPng.Chunks.Item[AX].Name);
//    end;

    tempPng.SaveToFile(targetPath + '\' + node.Name + '.png');
    tempPng.Free;
  end;

  png.Free;
  Json.Free;

end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ChangeWindowMessageFilter(WM_DROPFILES, MSGFLT_ADD);

  ChangeWindowMessageFilter(WM_COPYDATA, MSGFLT_ADD);

  ChangeWindowMessageFilter(WM_COPYGLOBALDATA , MSGFLT_ADD);

   DragAcceptFiles(Form1.Handle, True);
end;

procedure TForm1.WmDropFiles(var Msg: TMessage);
var
   P:array[0..511] of Char;
   i:Word;
begin
   Inherited;
   {$IFDEF WIN32}
      i:=DragQueryFile(Msg.wParam,$FFFFFFFF,nil,0);
   {$ELSE}
      i:=DragQueryFile(Msg.wParam,$FFFF,nil,0);
   {$ENDIF}
   for i:=0 to i-1 do
   begin
     DragQueryFile(Msg.wParam,i,P,512);
     DoUnPack(StrPas(P));
   end;

   mmo_log.Lines.Add('所有文件处理完成');
end;

{ TChunkIHDRHelper }

function TChunkIHDRHelper.GetPerPixelByteSize: Integer;
begin
  Result := BytesPerRow div Width;
end;

end.
