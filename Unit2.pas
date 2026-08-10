unit Unit2;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, uAliveGrid,
  FMX.StdCtrls, FMX.Controls.Presentation;

type
  TForm2 = class(TForm)
    Panel1: TPanel;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    { Private-Deklarationen }
    AliveGrid: TAliveGrid;
  public
    { Public-Deklarationen }
  end;

var
  Form2: TForm2;

implementation

{$R *.fmx}

procedure TForm2.Button1Click(Sender: TObject);
var
  XX : String;
begin
  XX := inttostr(Random(14));
  AliveGrid.AddItem('Caption '+XX,'Hint '+XX,'Filepath '+XX,XX+'.jpg');
end;

procedure TForm2.Button2Click(Sender: TObject);
begin
  AliveGrid.RemoveItem(1);
end;

procedure TForm2.FormCreate(Sender: TObject);
begin
  AliveGrid := TAliveGrid.Create(Self);
  AliveGrid.Parent := Self;
  AliveGrid.Align := TAlignLayout.Client;
  AliveGrid.Intensity := 0.5;
  AliveGrid.Active := True;
end;

end.
