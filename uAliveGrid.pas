{*******************************************************************************
  TAliveGrid - Liquid Slides Container Component for Delphi (FMX / Skia4Delphi)

  A high-performance, physics-based UI component that renders slides as
  liquid, particle-based blobs. Features include magnetic snap-in dots,
  drag-and-drop reordering, interactive mouse repulsion, and dynamic caching.

  Features:
  - ID-based Text & Content Caching: Prevents text cropping and flickering
    during resizing or dragging by mapping items via unique IDs.
  - Image Support: Implements KeepAspect (Letterbox) to center images
    proportionally with a BaseColor background fallback.
  - Stable Physics Engine: Verlet integration with distance constraints
    for fluid, jelly-like movements.
  - Threaded Rendering: Background thread calculates physics and redraws
    Skia caches asynchronously to keep the UI thread responsive.

  Author: Lara Miriam Tamy Reschke
  License: MIT

  Latest changes:
    v0.2:
      - Scrolling Support: Added full vertical scrolling logic,
        including mouse wheel interaction.
      - Custom Scrollbar: Implemented a dynamic,
        smoothly fading scrollbar button for visual scroll indication
        and direct dragging.
      - Virtualized Slide Pool: Added a dynamic pooling system that
        recycles slides based on the current scroll offset to handle
        large item lists efficiently.
      - Smooth Scroll Physics: Integrated fast-snap logic for slides
        during fast scrolling, pausing heavy physics calculations to
        maintain high frame rates.

*******************************************************************************}

unit uAliveGrid;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.SyncObjs,
  System.UITypes, FMX.Types, FMX.Controls, FMX.Graphics, FMX.Skia, System.Skia;

type
  TGridItemData = record
    Caption: string;
    Hint: string;
    FilePath: string;
    ImagePath: string;
    BaseColor: TAlphaColor;
    ImageBitmap: ISkImage;
  end;

  TGridParticle = record
    X, Y: Single;
    OldX, OldY: Single;
    VelX, VelY: Single;
    LocalAnchorX, LocalAnchorY: Single;
    ActivationTime: Cardinal;
  end;

  TControlDot = record
    X, Y: Single;
    OldX, OldY: Single;
    VelX, VelY: Single;
    LocalAnchorX, LocalAnchorY: Single;
    ActivationTime: Cardinal;
    ActualAlpha, TargetAlpha: Single;
  end;

  TGridSlide = record
    TargetX, TargetY: Single;
    CurrentX, CurrentY: Single;
    DragTargetX, DragTargetY: Single;
    Particles: array of TGridParticle;
    ControlDot: TControlDot;
    Cols, Rows: Integer;
    RestX, RestY, RestDiag: Single;
    IsRemoving: Boolean;
    IsDead: Boolean;
    IsDirty: Boolean;
    IsDragging: Boolean;
    MaxActivationTime: Cardinal;

    Cache: ISkImage;
    SlideSurface: ISkSurface;
    SlideSurfaceInfo: TSkImageInfo;
    ContentCache: ISkImage;
    ContentActualAlpha: Single;
    ContentTargetAlpha: Single;

    TopRightIdx: Integer;
    ActualSlideW, ActualSlideH: Single;
    ItemID: Integer;

    LogicalItemIdx: Integer;
  end;

  TSlideMouseEvent = procedure(Sender: TObject; SlideIdx: Integer; Button: TMouseButton; Shift: TShiftState; X, Y: Single) of object;

  TSlideNotifyEvent = procedure(Sender: TObject; SlideIdx: Integer) of object;

  TAliveGrid = class(TSkCustomControl)
  private
    FThread: TThread;
    FLock: TCriticalSection;
    FActive: Boolean;
    FIntensity: Single;
    FBackgroundImage: ISkImage;
    FMainSurface: ISkSurface;
    FMainSurfaceInfo: TSkImageInfo;
    FMainImage: ISkImage;
    FLastWidth, FLastHeight: Integer;
    FMousePos: TPointF;
    FIsMouseOver: Boolean;
    FCurrentWidth, FCurrentHeight: Single;
    FAnyDirty: Boolean;
    FIsResizing: Boolean;

    FDraggedSlideIdx: Integer;
    FDragOffsetX, FDragOffsetY: Single;
    FIsDragging: Boolean;
    FMouseDownPos: TPointF;
    FMouseIsDown: Boolean;
    FMouseDownSlideIdx: Integer;
    FMouseIsDownOnDot: Boolean;
    FNextItemID: Integer;
    FIsDraggingScrollBar: Boolean;
    FLastScrollTime: Cardinal;

    FTargetItemColor, FActualItemColor: TAlphaColor;
    FTargetShadowColor, FActualShadowColor: TAlphaColor;
    FTargetDotColor, FActualDotColor: TAlphaColor;

    FAllItems: array of TGridItemData;
    FAllItemIDs: array of Integer;
    FVisibleSlides: array of TGridSlide;

    FScrollOffset: Single;
    FMaxScroll: Single;
    FScrollBarDot: TControlDot;

    FFontName: string;
    FFontSize: Single;
    FFontIsBold: Boolean;
    FFontIsItalic: Boolean;
    FCaptionColor, FPathColor: TAlphaColor;

    FTextCache: ISkImage;
    FTextCacheSurface: ISkSurface;
    FTextCacheInfo: TSkImageInfo;
    FNeedsTextCacheUpdate: Boolean;

    FOnSlideMouseDown: TSlideMouseEvent;
    FOnDotMouseDown: TSlideMouseEvent;
    FOnSlideClick: TSlideNotifyEvent;
    FOnSlideDblClick: TSlideNotifyEvent;
    FOnDotClick: TSlideNotifyEvent;
    FOnDotDblClick: TSlideNotifyEvent;

    procedure SetActive(const Value: Boolean);
    procedure SetIntensity(const Value: Single);
    procedure SetItemColor(const Value: TAlphaColor);
    procedure SetShadowColor(const Value: TAlphaColor);
    procedure SetDotColor(const Value: TAlphaColor);
    procedure SetFontName(const Value: string);
    procedure SetFontSize(const Value: Single);
    procedure SetFontIsBold(const Value: Boolean);
    procedure SetFontIsItalic(const Value: Boolean);
    procedure SetCaptionColor(const Value: TAlphaColor);
    procedure SetPathColor(const Value: TAlphaColor);

    procedure SafeInvalidate;
    procedure DoRedraw;
    procedure StartThread;
    procedure StopThread;
    procedure DrawBackgroundCache;
    procedure UpdateTextCache;

    procedure UpdateVisibleSlides;
    procedure RecycleSlide(var ASlide: TGridSlide; NewLogicalIdx: Integer; Animate: Boolean);
    procedure PlaySpawnAnimation(var ASlide: TGridSlide);
    procedure UpdateSlideMapping;
    procedure UpdateTargets;
    procedure SwapDataItems(Idx1, Idx2: Integer);
    procedure GenerateContentCache(var ASlide: TGridSlide; const AData: TGridItemData);
    procedure ProcessSlidePhysics(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
    procedure ProcessSlideConstraints(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
    procedure ProcessSlideCaching(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single; const ABlurPaint, ABlackPaint, AContentPaint, AControlDotPaint, AHighlightPaint: ISkPaint);
    procedure ExecuteRenderLoop;

    function GetDotRect(Idx: Integer): TRectF;
    function FindItemIdxByID(ID: Integer): Integer;
    function IsLogicalIdxMapped(LogicalIdx: Integer): Boolean;
    function IsLogicalIdxDying(LogicalIdx: Integer): Boolean;
  protected
    procedure Resize; override;
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure DblClick; override;
    procedure MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure AddItem(const ACaption: string = ''; const AHint: string = ''; const AFilePath: string = ''; const AImagePath: string = '');
    procedure RemoveItem(Index: Integer);

    property Active: Boolean read FActive write SetActive;
    property Intensity: Single read FIntensity write SetIntensity;
  published
    property ItemColor: TAlphaColor read FTargetItemColor write SetItemColor default $FF080A12;
    property ShadowColor: TAlphaColor read FTargetShadowColor write SetShadowColor default $FF000000;
    property DotColor: TAlphaColor read FTargetDotColor write SetDotColor default $FF00838F;

    property FontName: string read FFontName write SetFontName;
    property FontSize: Single read FFontSize write SetFontSize;
    property FontIsBold: Boolean read FFontIsBold write SetFontIsBold;
    property FontIsItalic: Boolean read FFontIsItalic write SetFontIsItalic;

    property CaptionColor: TAlphaColor read FCaptionColor write SetCaptionColor default TAlphaColors.White;
    property PathColor: TAlphaColor read FPathColor write SetPathColor default $FF888888;

    property OnSlideMouseDown: TSlideMouseEvent read FOnSlideMouseDown write FOnSlideMouseDown;
    property OnDotMouseDown: TSlideMouseEvent read FOnDotMouseDown write FOnDotMouseDown;
    property OnSlideClick: TSlideNotifyEvent read FOnSlideClick write FOnSlideClick;
    property OnSlideDblClick: TSlideNotifyEvent read FOnSlideDblClick write FOnSlideDblClick;
    property OnDotClick: TSlideNotifyEvent read FOnDotClick write FOnDotClick;
    property OnDotDblClick: TSlideNotifyEvent read FOnDotDblClick write FOnDotDblClick;
  end;

implementation

const
  MinSpaceX = 28.0;
  SlideRows = 5;
  ParticleRadius = 14.0;
  BaseSlideH = 100;
  SlideGap = 80;
  BorderGap = 40;
  ScrollBarWidth = 6;
  ScrollBarHeight = 40;

function LerpColor(C1, C2: TAlphaColor; t: Single): TAlphaColor;
var
  A1, R1, G1, B1, A2, R2, G2, B2: Byte;
begin
  A1 := (C1 shr 24) and $FF;
  R1 := (C1 shr 16) and $FF;
  G1 := (C1 shr 8) and $FF;
  B1 := C1 and $FF;
  A2 := (C2 shr 24) and $FF;
  R2 := (C2 shr 16) and $FF;
  G2 := (C2 shr 8) and $FF;
  B2 := C2 and $FF;
  Result := (Round(A1 + (A2 - A1) * t) shl 24) or (Round(R1 + (R2 - R1) * t) shl 16) or (Round(G1 + (G2 - G1) * t) shl 8) or Round(B1 + (B2 - B1) * t);
end;

{ TAliveGrid }

constructor TAliveGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FLock := TCriticalSection.Create;
  HitTest := True;

  FActive := True;
  FIntensity := 0.2;
  FIsMouseOver := False;
  FCurrentWidth := 100;
  FCurrentHeight := 100;
  FMousePos := TPointF.Create(0, 0);

  FDraggedSlideIdx := -1;
  FIsDragging := False;
  FMouseIsDown := False;
  FIsResizing := False;
  FMouseDownSlideIdx := -1;
  FNextItemID := 1;
  FIsDraggingScrollBar := False;
  FLastScrollTime := 0;

  FScrollOffset := 0;
  FMaxScroll := 0;
  FScrollBarDot.TargetAlpha := 0;
  FScrollBarDot.ActualAlpha := 0;

  FTargetItemColor := $FF080A12;
  FActualItemColor := FTargetItemColor;
  FTargetShadowColor := $FF000000;
  FActualShadowColor := FTargetShadowColor;
  FTargetDotColor := $FF00838F;
  FActualDotColor := FTargetDotColor;

  FFontName := 'Segoe UI';
  FFontSize := 18;
  FFontIsBold := False;
  FFontIsItalic := False;
  FCaptionColor := TAlphaColors.White;
  FPathColor := $FF888888;

  FNeedsTextCacheUpdate := True;
  StartThread;
end;

destructor TAliveGrid.Destroy;
begin
  StopThread;
  FreeAndNil(FLock);
  inherited;
end;

function TAliveGrid.FindItemIdxByID(ID: Integer): Integer;
begin
  for Result := 0 to High(FAllItemIDs) do
    if FAllItemIDs[Result] = ID then
      Exit;
  Result := -1;
end;

function TAliveGrid.IsLogicalIdxMapped(LogicalIdx: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FVisibleSlides) do
    if (FVisibleSlides[i].LogicalItemIdx = LogicalIdx) and not FVisibleSlides[i].IsRemoving then
      Exit(True);
end;

// Prevents recycling of a slide that is currently in the dying/destruction state
function TAliveGrid.IsLogicalIdxDying(LogicalIdx: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(FVisibleSlides) do
    if (FVisibleSlides[i].LogicalItemIdx = LogicalIdx) and FVisibleSlides[i].IsRemoving then
      Exit(True);
end;

procedure TAliveGrid.SetActive(const Value: Boolean);
begin
  FActive := Value;
end;

procedure TAliveGrid.SetIntensity(const Value: Single);
begin
  if FIntensity <> Value then
  begin
    FIntensity := EnsureRange(Value, 0.0, 1.0);
    DrawBackgroundCache;
    FAnyDirty := True;
    Redraw;
  end;
end;

procedure TAliveGrid.SetItemColor(const Value: TAlphaColor);
begin
  if FTargetItemColor <> Value then
  begin
    FTargetItemColor := Value;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetShadowColor(const Value: TAlphaColor);
begin
  if FTargetShadowColor <> Value then
  begin
    FTargetShadowColor := Value;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetDotColor(const Value: TAlphaColor);
begin
  if FTargetDotColor <> Value then
  begin
    FTargetDotColor := Value;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetFontName(const Value: string);
begin
  if FFontName <> Value then
  begin
    FFontName := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetFontSize(const Value: Single);
begin
  if not SameValue(FFontSize, Value) then
  begin
    FFontSize := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetFontIsBold(const Value: Boolean);
begin
  if FFontIsBold <> Value then
  begin
    FFontIsBold := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetFontIsItalic(const Value: Boolean);
begin
  if FFontIsItalic <> Value then
  begin
    FFontIsItalic := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetCaptionColor(const Value: TAlphaColor);
begin
  if FCaptionColor <> Value then
  begin
    FCaptionColor := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.SetPathColor(const Value: TAlphaColor);
begin
  if FPathColor <> Value then
  begin
    FPathColor := Value;
    FNeedsTextCacheUpdate := True;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.AddItem(const ACaption, AHint, AFilePath, AImagePath: string);
const
  Colors: array[0..4] of TAlphaColor = ($FFD32F2F, $FF1976D2, $FF388E3C, $FFFBC02D, $FF7B1FA2);
var
  LIdx, i: Integer;
  LOrigImg: ISkImage;
  LThumbSurface: ISkSurface;
  LScale, LOffX, LOffY: Single;
begin
  FLock.Acquire;
  try
    LIdx := Length(FAllItems);
    SetLength(FAllItems, LIdx + 1);
    SetLength(FAllItemIDs, LIdx + 1);

    if ACaption = '' then
      FAllItems[LIdx].Caption := 'Item ' + IntToStr(LIdx + 1)
    else
      FAllItems[LIdx].Caption := ACaption;

    FAllItems[LIdx].Hint := AHint;
    FAllItems[LIdx].FilePath := AFilePath;
    FAllItems[LIdx].ImagePath := AImagePath;
    FAllItems[LIdx].BaseColor := Colors[LIdx mod Length(Colors)];
    FAllItems[LIdx].ImageBitmap := nil;

    // Load and generate thumbnail if an image path is provided
    if (AImagePath <> '') and FileExists(AImagePath) then
    begin
      try
        LOrigImg := TSkImage.MakeFromEncodedFile(AImagePath);
        LThumbSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(BaseSlideH, BaseSlideH));
        LThumbSurface.Canvas.Clear(TAlphaColors.Null);

        LScale := Min(BaseSlideH / LOrigImg.Width, BaseSlideH / LOrigImg.Height);
        LOffX := (BaseSlideH - LOrigImg.Width * LScale) / 2;
        LOffY := (BaseSlideH - LOrigImg.Height * LScale) / 2;

        LThumbSurface.Canvas.DrawImageRect(LOrigImg, TRectF.Create(0, 0, LOrigImg.Width, LOrigImg.Height), TRectF.Create(LOffX, LOffY, LOffX + LOrigImg.Width * LScale, LOffY + LOrigImg.Height * LScale), TSkSamplingOptions.Medium, nil);
        FAllItems[LIdx].ImageBitmap := LThumbSurface.MakeImageSnapshot;
      except
        FAllItems[LIdx].ImageBitmap := nil;
      end;
    end;

    FAllItemIDs[LIdx] := FNextItemID;
    Inc(FNextItemID);

    FNeedsTextCacheUpdate := True;
    UpdateTextCache;

    UpdateVisibleSlides;

    // Trigger spawn animation for the newly added item if visible
    for i := 0 to High(FVisibleSlides) do
    begin
      if FVisibleSlides[i].LogicalItemIdx = LIdx then
      begin
        if (FVisibleSlides[i].TargetY > -BaseSlideH) and (FVisibleSlides[i].TargetY < FCurrentHeight) then
          PlaySpawnAnimation(FVisibleSlides[i]);
        Break;
      end;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TAliveGrid.RemoveItem(Index: Integer);
var
  i: Integer;
begin
  FLock.Acquire;
  try
    if (Index >= 0) and (Index <= High(FAllItems)) then
    begin
      System.Delete(FAllItems, Index, 1);
      System.Delete(FAllItemIDs, Index, 1);
    end;

    // Mark associated slide for removal and instantly clear content cache
    for i := 0 to High(FVisibleSlides) do
    begin
      if FVisibleSlides[i].LogicalItemIdx = Index then
      begin
        FVisibleSlides[i].IsRemoving := True;
        FVisibleSlides[i].IsDirty := True;

        FVisibleSlides[i].ContentCache := nil;
        FVisibleSlides[i].ContentTargetAlpha := 0;
        FVisibleSlides[i].ContentActualAlpha := 0;
        FVisibleSlides[i].ControlDot.TargetAlpha := 0;
        FVisibleSlides[i].LogicalItemIdx := -1;
      end;
    end;

    // Shift logical indices for slides that come after the removed item
    for i := 0 to High(FVisibleSlides) do
    begin
      if (not FVisibleSlides[i].IsRemoving) and (FVisibleSlides[i].LogicalItemIdx > Index) then
        Dec(FVisibleSlides[i].LogicalItemIdx);
    end;

    FNeedsTextCacheUpdate := True;
    UpdateTextCache;

    FMaxScroll := Max(0, ((Length(FAllItems) - 1) * (BaseSlideH + SlideGap)) + BaseSlideH + (2 * BorderGap) - FCurrentHeight);
    FScrollOffset := EnsureRange(FScrollOffset, 0, FMaxScroll);
    UpdateSlideMapping;
    UpdateTargets;
  finally
    FLock.Release;
  end;
end;

procedure TAliveGrid.UpdateVisibleSlides;
var
  VisibleCount, PoolSize, LIdx, i: Integer;
  ItemH: Single;
  SpaceX, SpaceY: Single;
  j, RequiredCols: Integer;
begin
  if FCurrentHeight <= BorderGap + BaseSlideH then
    VisibleCount := 0
  else
    VisibleCount := Floor((FCurrentHeight - BorderGap) / (BaseSlideH + SlideGap)) + 1;

  // Create a pool slightly larger than visible count for smooth scrolling
  PoolSize := VisibleCount + 4;
  if PoolSize < 0 then
    PoolSize := 0;

  if Length(FAllItems) < PoolSize then
    PoolSize := Length(FAllItems);

  // Initialize new slides in the pool
  while Length(FVisibleSlides) < PoolSize do
  begin
    LIdx := Length(FVisibleSlides);
    SetLength(FVisibleSlides, LIdx + 1);

    FVisibleSlides[LIdx].LogicalItemIdx := -1;
    FVisibleSlides[LIdx].TargetY := FCurrentHeight + 1000;
    FVisibleSlides[LIdx].CurrentY := FVisibleSlides[LIdx].TargetY;

    FVisibleSlides[LIdx].ActualSlideW := FCurrentWidth - (BorderGap * 2);
    FVisibleSlides[LIdx].ActualSlideH := BaseSlideH;

    RequiredCols := Max(10, Round(FVisibleSlides[LIdx].ActualSlideW / MinSpaceX));
    FVisibleSlides[LIdx].Cols := RequiredCols;
    FVisibleSlides[LIdx].Rows := SlideRows;
    SetLength(FVisibleSlides[LIdx].Particles, FVisibleSlides[LIdx].Cols * SlideRows);
    FVisibleSlides[LIdx].TopRightIdx := (FVisibleSlides[LIdx].Cols - 1) * FVisibleSlides[LIdx].Rows;

    SpaceX := FVisibleSlides[LIdx].ActualSlideW / (FVisibleSlides[LIdx].Cols - 1);
    SpaceY := FVisibleSlides[LIdx].ActualSlideH / (FVisibleSlides[LIdx].Rows - 1);
    FVisibleSlides[LIdx].RestX := SpaceX;
    FVisibleSlides[LIdx].RestY := SpaceY;
    FVisibleSlides[LIdx].RestDiag := Sqrt(SpaceX * SpaceX + SpaceY * SpaceY);

    FVisibleSlides[LIdx].ControlDot.LocalAnchorX := FVisibleSlides[LIdx].ActualSlideW - 21;
    FVisibleSlides[LIdx].ControlDot.LocalAnchorY := 21;

    // Initialize particle local anchors based on grid spacing
    for j := 0 to High(FVisibleSlides[LIdx].Particles) do
    begin
      FVisibleSlides[LIdx].Particles[j].LocalAnchorX := (j div SlideRows) * SpaceX;
      FVisibleSlides[LIdx].Particles[j].LocalAnchorY := (j mod SlideRows) * SpaceY;
      FVisibleSlides[LIdx].Particles[j].X := FVisibleSlides[LIdx].CurrentX + FVisibleSlides[LIdx].Particles[j].LocalAnchorX;
      FVisibleSlides[LIdx].Particles[j].Y := FVisibleSlides[LIdx].CurrentY + FVisibleSlides[LIdx].Particles[j].LocalAnchorY;
      FVisibleSlides[LIdx].Particles[j].OldX := FVisibleSlides[LIdx].Particles[j].X;
      FVisibleSlides[LIdx].Particles[j].OldY := FVisibleSlides[LIdx].Particles[j].Y;
      FVisibleSlides[LIdx].Particles[j].VelX := 0;
      FVisibleSlides[LIdx].Particles[j].VelY := 0;
    end;
  end;

  while Length(FVisibleSlides) > PoolSize do
    System.Delete(FVisibleSlides, High(FVisibleSlides), 1);

  ItemH := BaseSlideH + SlideGap;
  if Length(FAllItems) > 0 then
    FMaxScroll := Max(0, ((Length(FAllItems) - 1) * ItemH) + BaseSlideH + (2 * BorderGap) - FCurrentHeight)
  else
    FMaxScroll := 0;

  FScrollOffset := EnsureRange(FScrollOffset, 0, FMaxScroll);

  UpdateSlideMapping;
  UpdateTargets;
end;

procedure TAliveGrid.UpdateSlideMapping;
var
  i, j, MissingIdx, FirstNeeded, LastNeeded: Integer;
  ItemH: Single;
  MissingIndices: array of Integer;
begin
  if Length(FAllItems) = 0 then
    Exit;
  if FIsDragging then
    Exit;

  ItemH := BaseSlideH + SlideGap;
  FirstNeeded := Floor(FScrollOffset / ItemH) - 1;
  LastNeeded := Floor((FScrollOffset + FCurrentHeight) / ItemH) + 1;

  // Gather missing logical indices that should be visible
  for j := FirstNeeded to LastNeeded do
  begin
    if (j >= 0) and (j < Length(FAllItems)) then
    begin
      if (not IsLogicalIdxMapped(j)) and (not IsLogicalIdxDying(j)) then
      begin
        SetLength(MissingIndices, Length(MissingIndices) + 1);
        MissingIndices[High(MissingIndices)] := j;
      end;
    end;
  end;

  // Assign missing indices to unused or out-of-bounds slides
  for i := 0 to High(FVisibleSlides) do
  begin
    if FVisibleSlides[i].IsRemoving or FVisibleSlides[i].IsDragging then
      Continue;

    if (FVisibleSlides[i].LogicalItemIdx = -1) or (FVisibleSlides[i].LogicalItemIdx < FirstNeeded) or (FVisibleSlides[i].LogicalItemIdx > LastNeeded) then
    begin
      if Length(MissingIndices) > 0 then
      begin
        MissingIdx := MissingIndices[High(MissingIndices)];
        SetLength(MissingIndices, Length(MissingIndices) - 1);
        RecycleSlide(FVisibleSlides[i], MissingIdx, False);
      end
      else
      begin
        if FVisibleSlides[i].LogicalItemIdx <> -1 then
        begin
          FVisibleSlides[i].LogicalItemIdx := -1;
          FVisibleSlides[i].TargetY := FCurrentHeight + 1000;
          FVisibleSlides[i].CurrentY := FVisibleSlides[i].TargetY;
          FVisibleSlides[i].IsDirty := True;
        end;
      end;
    end;
  end;
end;

procedure TAliveGrid.RecycleSlide(var ASlide: TGridSlide; NewLogicalIdx: Integer; Animate: Boolean);
var
  i: Integer;
begin
  if (NewLogicalIdx < 0) or (NewLogicalIdx > High(FAllItems)) then
    Exit;

  ASlide.LogicalItemIdx := NewLogicalIdx;
  ASlide.ItemID := FAllItemIDs[NewLogicalIdx];
  ASlide.IsRemoving := False;
  ASlide.IsDead := False;

  ASlide.ActualSlideW := FCurrentWidth - (BorderGap * 2);
  ASlide.ActualSlideH := BaseSlideH;

  ASlide.TargetX := BorderGap;
  ASlide.TargetY := BorderGap + (NewLogicalIdx * (BaseSlideH + SlideGap)) - FScrollOffset;

  ASlide.CurrentX := ASlide.TargetX;
  ASlide.CurrentY := ASlide.TargetY;

  // Reset particles to their anchor positions inside the slide
  for i := 0 to High(ASlide.Particles) do
  begin
    ASlide.Particles[i].X := ASlide.CurrentX + ASlide.Particles[i].LocalAnchorX;
    ASlide.Particles[i].Y := ASlide.CurrentY + ASlide.Particles[i].LocalAnchorY;
    ASlide.Particles[i].OldX := ASlide.Particles[i].X;
    ASlide.Particles[i].OldY := ASlide.Particles[i].Y;
    ASlide.Particles[i].VelX := 0;
    ASlide.Particles[i].VelY := 0;
    ASlide.Particles[i].ActivationTime := 0;
  end;

  ASlide.ControlDot.X := ASlide.CurrentX + ASlide.ControlDot.LocalAnchorX;
  ASlide.ControlDot.Y := ASlide.CurrentY + ASlide.ControlDot.LocalAnchorY;
  ASlide.ControlDot.TargetAlpha := 1.0;
  ASlide.ControlDot.ActualAlpha := 1.0;

  // Only restore content alpha if the slide isn't currently fading out
  if ASlide.ContentTargetAlpha <> 0 then
  begin
    ASlide.ContentTargetAlpha := 1.0;
    ASlide.ContentActualAlpha := 1.0;
  end;

  GenerateContentCache(ASlide, FAllItems[NewLogicalIdx]);
  ASlide.IsDirty := True;

  if Animate then
    PlaySpawnAnimation(ASlide);
end;

procedure TAliveGrid.PlaySpawnAnimation(var ASlide: TGridSlide);
var
  i, j: Integer;
  SpaceX, SpaceY, StartX, StartY: Single;
  BaseTime: Cardinal;
begin
  SpaceX := ASlide.ActualSlideW / (ASlide.Cols - 1);
  SpaceY := ASlide.ActualSlideH / (ASlide.Rows - 1);
  StartX := FCurrentWidth / 2;
  StartY := FCurrentHeight + 50;
  BaseTime := TThread.GetTickCount;

  ASlide.IsDirty := True;
  ASlide.ContentActualAlpha := 0;
  ASlide.ContentTargetAlpha := 0;
  ASlide.ControlDot.ActualAlpha := 0;
  ASlide.ControlDot.TargetAlpha := 0;
  ASlide.ControlDot.ActivationTime := BaseTime + 1200;

  // Calculate staggered activation times for particles to create a flying-in effect
  ASlide.MaxActivationTime := 0;
  for i := 0 to ASlide.Cols - 1 do
  begin
    for j := 0 to ASlide.Rows - 1 do
    begin
      ASlide.Particles[i * ASlide.Rows + j].X := StartX + (i * 2) - 10;
      ASlide.Particles[i * ASlide.Rows + j].Y := StartY + (i * 4) + (j * 15);
      ASlide.Particles[i * ASlide.Rows + j].OldX := ASlide.Particles[i * ASlide.Rows + j].X;
      ASlide.Particles[i * ASlide.Rows + j].OldY := ASlide.Particles[i * ASlide.Rows + j].Y;
      ASlide.Particles[i * ASlide.Rows + j].VelX := 0;
      ASlide.Particles[i * ASlide.Rows + j].VelY := -15;
      ASlide.Particles[i * ASlide.Rows + j].ActivationTime := BaseTime + Cardinal(i * 60);
      if ASlide.Particles[i * ASlide.Rows + j].ActivationTime > ASlide.MaxActivationTime then
        ASlide.MaxActivationTime := ASlide.Particles[i * ASlide.Rows + j].ActivationTime;
    end;
  end;
  ASlide.MaxActivationTime := ASlide.MaxActivationTime + 500;
end;

procedure TAliveGrid.UpdateTargets;
var
  i: Integer;
begin
  for i := 0 to High(FVisibleSlides) do
  begin
    FVisibleSlides[i].ActualSlideW := FCurrentWidth - (BorderGap * 2);
    FVisibleSlides[i].ActualSlideH := BaseSlideH;

    if not FVisibleSlides[i].IsDragging then
    begin
      FVisibleSlides[i].TargetX := BorderGap;
      if (FVisibleSlides[i].LogicalItemIdx >= 0) and (not FVisibleSlides[i].IsRemoving) then
        FVisibleSlides[i].TargetY := BorderGap + (FVisibleSlides[i].LogicalItemIdx * (BaseSlideH + SlideGap)) - FScrollOffset
      else
        FVisibleSlides[i].TargetY := FCurrentHeight + 1000;
    end;
    FVisibleSlides[i].IsDirty := True;
  end;
  FAnyDirty := True;
end;

procedure TAliveGrid.SwapDataItems(Idx1, Idx2: Integer);
var
  TempData: TGridItemData;
  TempID: Integer;
begin
  if (Idx1 < 0) or (Idx1 > High(FAllItems)) or (Idx2 < 0) or (Idx2 > High(FAllItems)) or (Idx1 = Idx2) then
    Exit;

  TempData := FAllItems[Idx1];
  FAllItems[Idx1] := FAllItems[Idx2];
  FAllItems[Idx2] := TempData;

  TempID := FAllItemIDs[Idx1];
  FAllItemIDs[Idx1] := FAllItemIDs[Idx2];
  FAllItemIDs[Idx2] := TempID;

  FNeedsTextCacheUpdate := True;
  UpdateTextCache;
end;

procedure TAliveGrid.UpdateTextCache;
var
  i, LCount: Integer;
  LPaint: ISkPaint;
  LFont, LTinyFont: ISkFont;
  LSkStyle: TSkFontStyle;
  LTypeface: ISkTypeface;
begin
  if not FNeedsTextCacheUpdate then
    Exit;

  LCount := Length(FAllItems);
  if LCount = 0 then
  begin
    FTextCache := nil;
    FNeedsTextCacheUpdate := False;
    Exit;
  end;

  LSkStyle := TSkFontStyle.Normal;
  if FFontIsBold then
    LSkStyle := TSkFontStyle.Bold;
  if FFontIsItalic then
    LSkStyle := TSkFontStyle.Italic;

  LTypeface := TSkTypeface.MakeFromName(FFontName, LSkStyle);
  LFont := TSkFont.Create(LTypeface, FFontSize);
  LTinyFont := TSkFont.Create(LTypeface, 10);

  // Create a large surface holding all text entries to reduce draw calls
  FTextCacheInfo := TSkImageInfo.Create(Round(FCurrentWidth), LCount * BaseSlideH);
  FTextCacheSurface := TSkSurface.MakeRaster(FTextCacheInfo);
  FTextCacheSurface.Canvas.Clear(TAlphaColors.Null);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  for i := 0 to LCount - 1 do
  begin
    LPaint.Color := FCaptionColor;
    FTextCacheSurface.Canvas.DrawSimpleText(FAllItems[i].Caption, BaseSlideH + 10, 25 + (i * BaseSlideH), LFont, LPaint);

    if FAllItems[i].FilePath <> '' then
    begin
      LPaint.Color := FPathColor;
      FTextCacheSurface.Canvas.DrawSimpleText(FAllItems[i].FilePath, BaseSlideH + 10, 70 + (i * BaseSlideH), LTinyFont, LPaint);
    end;
  end;

  FTextCache := FTextCacheSurface.MakeImageSnapshot;
  FNeedsTextCacheUpdate := False;
end;

procedure TAliveGrid.GenerateContentCache(var ASlide: TGridSlide; const AData: TGridItemData);
var
  LSurface: ISkSurface;
  LPaint: ISkPaint;
  LRect: TRectF;
  FadeColor: TAlphaColor;
  ItemIdx: Integer;
begin
  LSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(Round(ASlide.ActualSlideW), Round(ASlide.ActualSlideH)));
  LSurface.Canvas.Clear(TAlphaColors.Null);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;
  FadeColor := FActualItemColor;

  ItemIdx := FindItemIdxByID(ASlide.ItemID);

  LRect := TRectF.Create(0, 0, BaseSlideH, BaseSlideH);
  if AData.ImageBitmap <> nil then
  begin
    LSurface.Canvas.DrawImage(AData.ImageBitmap, 0, 0, LPaint);
  end
  else
  begin
    LPaint.Color := AData.BaseColor;
    LSurface.Canvas.DrawRect(LRect, LPaint);
  end;

  // Draw the specific text segment from the global text cache
  if (ItemIdx <> -1) and (FTextCache <> nil) then
    LSurface.Canvas.DrawImageRect(FTextCache, TRectF.Create(0, ItemIdx * BaseSlideH, ASlide.ActualSlideW, (ItemIdx + 1) * BaseSlideH), TRectF.Create(0, 0, ASlide.ActualSlideW, BaseSlideH), TSkSamplingOptions.Medium, LPaint);

  LPaint.Color := FadeColor;

  // Draw gradient edges to smoothly blend the image corners into the background
  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, 0), TPointF.Create(0, 15), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, 0, BaseSlideH, 15), LPaint);

  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, BaseSlideH), TPointF.Create(0, BaseSlideH - 15), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, BaseSlideH - 15, BaseSlideH, BaseSlideH), LPaint);

  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, 0), TPointF.Create(15, 0), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, 0, 15, BaseSlideH), LPaint);

  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(BaseSlideH, 0), TPointF.Create(BaseSlideH - 15, 0), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(BaseSlideH - 15, 0, BaseSlideH, BaseSlideH), LPaint);

  ASlide.ContentCache := LSurface.MakeImageSnapshot;
end;

procedure TAliveGrid.ProcessSlidePhysics(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
var
  i: Integer;
  Ldx, Ldy, LDist, LForce, LRepelRadius: Single;
begin
  LRepelRadius := 70.0;

  with ASlide do
  begin
    // Update Slide Root Position
    if not IsRemoving then
    begin
      if IsDragging then
      begin
        // Snap directly to drag target for immediate response
        CurrentX := DragTargetX;
        CurrentY := DragTargetY;
      end
      else
      begin
        // Smoothly interpolate to target position
        CurrentX := CurrentX + (TargetX - CurrentX) * 0.09;
        CurrentY := CurrentY + (TargetY - CurrentY) * 0.09;
      end;
    end;

    // Update Particles
    for i := 0 to High(Particles) do
    begin
      // Mouse Repulsion Effect
      if FIsMouseOver and not IsDragging and not IsRemoving then
      begin
        Ldx := Particles[i].X - FMousePos.X;
        Ldy := Particles[i].Y - FMousePos.Y;
        LDist := Sqrt(Ldx * Ldx + Ldy * Ldy);
        if LDist < LRepelRadius then
        begin
          LForce := (1.0 - (LDist / LRepelRadius));
          LForce := LForce * LForce * 15.0; // Exponential falloff for natural feel
          if LDist > 0 then
          begin
            Particles[i].VelX := Particles[i].VelX + (Ldx / LDist) * LForce;
            Particles[i].VelY := Particles[i].VelY + (Ldy / LDist) * LForce;
          end;
        end;
      end;

      // Apply gravity when slide is being removed
      if IsRemoving then
        Particles[i].VelY := Particles[i].VelY + 2.5;

      // Apply Damping (Friction)
      Particles[i].VelX := Particles[i].VelX * 0.85;
      Particles[i].VelY := Particles[i].VelY * 0.85;

      // Clamp velocities to prevent physics explosions
      Particles[i].VelX := EnsureRange(Particles[i].VelX, -40, 40);
      Particles[i].VelY := EnsureRange(Particles[i].VelY, -40, 40);

      // Store old positions for Verlet integration
      Particles[i].OldX := Particles[i].X;
      Particles[i].OldY := Particles[i].Y;

      // Apply velocity
      Particles[i].X := Particles[i].X + Particles[i].VelX;
      Particles[i].Y := Particles[i].Y + Particles[i].VelY;
    end;
  end;
end;

procedure TAliveGrid.ProcessSlideConstraints(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
var
  i, j, Idx1, Idx2, iter: Integer;
  Ldx, Ldy, LDist, LTargetX, LTargetY, LDiff: Single;
begin
  with ASlide do
  begin
    // Iterate constraints multiple times for stability
    for iter := 0 to 2 do
    begin
      for i := 0 to High(Particles) do
      begin
        if IsRemoving then
        begin
          // Collapse towards bottom center when dying
          LTargetX := LW / 2;
          LTargetY := LH + 150;
          Particles[i].X := Particles[i].X + (LTargetX - Particles[i].X) * 0.05;
          Particles[i].Y := Particles[i].Y + (LTargetY - Particles[i].Y) * 0.05;
        end
        else if NowTime < Particles[i].ActivationTime then
        begin
          // Pre-activation: Hover below the slide waiting to fly in
          LTargetX := CurrentX + (i * 2) - 10;
          LTargetY := CurrentY + ActualSlideH + 15;
          Particles[i].X := Particles[i].X + (LTargetX - Particles[i].X) * 0.08;
          Particles[i].Y := Particles[i].Y + (LTargetY - Particles[i].Y) * 0.08;
        end
        else
        begin
          // Post-activation: Pull towards local anchor inside the slide
          LTargetX := CurrentX + Particles[i].LocalAnchorX;
          LTargetY := CurrentY + Particles[i].LocalAnchorY;
          Particles[i].X := Particles[i].X + (LTargetX - Particles[i].X) * 0.08;
          Particles[i].Y := Particles[i].Y + (LTargetY - Particles[i].Y) * 0.08;
        end;
      end;

      // Constraint 1: Horizontal neighbors
      for i := 0 to Cols - 2 do
        for j := 0 to Rows - 1 do
        begin
          Idx1 := i * Rows + j;
          Idx2 := (i + 1) * Rows + j;
          Ldx := Particles[Idx2].X - Particles[Idx1].X;
          Ldy := Particles[Idx2].Y - Particles[Idx1].Y;
          LDist := Sqrt(Ldx * Ldx + Ldy * Ldy);
          if LDist > 0.1 then
          begin
            LDiff := (LDist - ASlide.RestX) / LDist * 0.3;
            Particles[Idx1].X := Particles[Idx1].X + Ldx * LDiff;
            Particles[Idx1].Y := Particles[Idx1].Y + Ldy * LDiff;
            Particles[Idx2].X := Particles[Idx2].X - Ldx * LDiff;
            Particles[Idx2].Y := Particles[Idx2].Y - Ldy * LDiff;
          end;
        end;

      // Constraint 2: Vertical neighbors
      for i := 0 to Cols - 1 do
        for j := 0 to Rows - 2 do
        begin
          Idx1 := i * Rows + j;
          Idx2 := i * Rows + (j + 1);
          Ldx := Particles[Idx2].X - Particles[Idx1].X;
          Ldy := Particles[Idx2].Y - Particles[Idx1].Y;
          LDist := Sqrt(Ldx * Ldx + Ldy * Ldy);
          if LDist > 0.1 then
          begin
            LDiff := (LDist - ASlide.RestY) / LDist * 0.3;
            Particles[Idx1].X := Particles[Idx1].X + Ldx * LDiff;
            Particles[Idx1].Y := Particles[Idx1].Y + Ldy * LDiff;
            Particles[Idx2].X := Particles[Idx2].X - Ldx * LDiff;
            Particles[Idx2].Y := Particles[Idx2].Y - Ldy * LDiff;
          end;
        end;

      // Constraint 3: Diagonal neighbors (prevents shearing/collapsing)
      for i := 0 to Cols - 2 do
        for j := 0 to Rows - 2 do
        begin
          Idx1 := i * Rows + j;
          Idx2 := (i + 1) * Rows + (j + 1);
          Ldx := Particles[Idx2].X - Particles[Idx1].X;
          Ldy := Particles[Idx2].Y - Particles[Idx1].Y;
          LDist := Sqrt(Ldx * Ldx + Ldy * Ldy);
          if LDist > 0.1 then
          begin
            LDiff := (LDist - ASlide.RestDiag) / LDist * 0.3;
            Particles[Idx1].X := Particles[Idx1].X + Ldx * LDiff;
            Particles[Idx1].Y := Particles[Idx1].Y + Ldy * LDiff;
            Particles[Idx2].X := Particles[Idx2].X - Ldx * LDiff;
            Particles[Idx2].Y := Particles[Idx2].Y - Ldy * LDiff;
          end;
        end;
    end;

    // Calculate final velocities based on position delta
    for i := 0 to High(Particles) do
    begin
      Particles[i].VelX := Particles[i].X - Particles[i].OldX;
      Particles[i].VelY := Particles[i].Y - Particles[i].OldY;
    end;
  end;
end;

procedure TAliveGrid.ProcessSlideCaching(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single; const ABlurPaint, ABlackPaint, AContentPaint, AControlDotPaint, AHighlightPaint: ISkPaint);
var
  LBuilder: ISkPathBuilder;
  LPath: ISkPath;
  TempImg: ISkImage;
  C1, C2: TAlphaColor;
  DotAlpha, ContentAlpha: Single;
  FAlphaByte, DR, DG, DB: Byte;
  i: Integer;
  LTargetX, LTargetY, LDistToMouse: Single;
begin
  with ASlide do
  begin
    LTargetX := Particles[TopRightIdx].X + 7;
    LTargetY := Particles[TopRightIdx].Y - 7;

    // Control dot follows mouse if close enough, otherwise snaps to top right
    if FIsMouseOver and not IsDragging and not IsRemoving then
    begin
      LDistToMouse := Sqrt(Sqr(FMousePos.X - LTargetX) + Sqr(FMousePos.Y - LTargetY));
      if LDistToMouse <= 10.0 then
      begin
        ControlDot.X := FMousePos.X;
        ControlDot.Y := FMousePos.Y;
      end
      else
      begin
        ControlDot.X := LTargetX;
        ControlDot.Y := LTargetY;
      end;
    end
    else
    begin
      ControlDot.X := LTargetX;
      ControlDot.Y := LTargetY;
    end;

    if (NowTime > ControlDot.ActivationTime) and (ControlDot.TargetAlpha < 1.0) and not FIsResizing then
    begin
      ControlDot.TargetAlpha := 1.0;
      ContentTargetAlpha := 1.0;
    end;

    if (NowTime > ControlDot.ActivationTime) and not IsRemoving then
    begin
      if ControlDot.TargetAlpha < 1.0 then
        ControlDot.TargetAlpha := 1.0;

      if ContentTargetAlpha < 1.0 then
        ContentTargetAlpha := 1.0;
    end;

    ControlDot.ActualAlpha := ControlDot.ActualAlpha + (ControlDot.TargetAlpha - ControlDot.ActualAlpha) * 0.05;
    ContentActualAlpha := ContentActualAlpha + (ContentTargetAlpha - ContentActualAlpha) * 0.05;

    // Reallocate slide surface if dimensions changed
    if (SlideSurface = nil) or (SlideSurfaceInfo.Width <> Round(LW)) or (SlideSurfaceInfo.Height <> Round(LH)) then
    begin
      SlideSurfaceInfo := TSkImageInfo.Create(Round(LW), Round(LH));
      SlideSurface := TSkSurface.MakeRaster(SlideSurfaceInfo);
    end;

    SlideSurface.Canvas.Clear(TAlphaColors.Null);

    // Construct path of all particle circles to form the liquid blob
    LBuilder := TSkPathBuilder.Create;
    LBuilder.FillType := TSkPathFillType.Winding;
    for i := 0 to High(Particles) do
      LBuilder.AddCircle(Particles[i].X, Particles[i].Y, ParticleRadius);
    LPath := LBuilder.Detach;

    // Draw blurred blob and then overlay it with the black/shadow paint
    SlideSurface.Canvas.DrawPath(LPath, ABlurPaint);
    TempImg := SlideSurface.MakeImageSnapshot;

    SlideSurface.Canvas.Clear(TAlphaColors.Null);
    SlideSurface.Canvas.DrawImage(TempImg, 0, 0, ABlackPaint);

    // Draw content cache (image + text) with fading
    ContentAlpha := ContentActualAlpha;
    if (ContentAlpha > 0.01) and (ContentCache <> nil) then
    begin
      AContentPaint.AlphaF := ContentAlpha;

      if IsDragging or (Abs(CurrentX - TargetX) > 0.5) or (Abs(CurrentY - TargetY) > 0.5) then
        SlideSurface.Canvas.DrawImage(ContentCache, Particles[0].X, Particles[0].Y, AContentPaint)
      else
        SlideSurface.Canvas.DrawImage(ContentCache, CurrentX, CurrentY, AContentPaint);
    end;

    // Draw control dot with radial gradient and highlight
    DotAlpha := ControlDot.ActualAlpha;
    if DotAlpha > 0.01 then
    begin
      FAlphaByte := Round(((FActualDotColor shr 24) and $FF) * DotAlpha);
      C1 := (FAlphaByte shl 24) or (FActualDotColor and $00FFFFFF);

      DR := ((FActualDotColor shr 16) and $FF) div 3;
      DG := ((FActualDotColor shr 8) and $FF) div 3;
      DB := (FActualDotColor and $FF) div 3;
      C2 := (FAlphaByte shl 24) or (DR shl 16) or (DG shl 8) or DB;

      AControlDotPaint.Shader := TSkShader.MakeGradientRadial(TPointF.Create(ControlDot.X - 3, ControlDot.Y - 3), 15, C1, C2, TSkTileMode.Clamp);
      SlideSurface.Canvas.DrawCircle(ControlDot.X, ControlDot.Y, 9, AControlDotPaint);

      AHighlightPaint.Color := (Round($CC * DotAlpha) shl 24) or $00FFFFFF;
      SlideSurface.Canvas.DrawCircle(ControlDot.X - 3, ControlDot.Y - 3, 2.5, AHighlightPaint);
    end;

    Cache := SlideSurface.MakeImageSnapshot;
    IsDirty := False;
  end;
end;

procedure TAliveGrid.DrawBackgroundCache;
var
  LDotPaint: ISkPaint;
  x, y: Integer;
  LPoint: TPointF;
  LRadius: Single;
  LColor, DarkBlue, BrightBlue: TAlphaColor;
  LSurface: ISkSurface;
begin
  if (FLastWidth <= 0) or (FLastHeight <= 0) then
    Exit;

  LSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(FLastWidth, FLastHeight));
  LSurface.Canvas.Clear(TAlphaColors.Black);

  LDotPaint := TSkPaint.Create;
  LDotPaint.AntiAlias := True;
  DarkBlue := $FF050015;
  BrightBlue := $FF0055FF;

  // Draw dotted grid pattern based on intensity
  for x := 0 to (FLastWidth div 10) do
  begin
    for y := 0 to (FLastHeight div 10) do
    begin
      LRadius := 2.0 + (FIntensity * 2.0);
      LColor := LerpColor(DarkBlue, BrightBlue, FIntensity);
      LDotPaint.Color := LColor;
      LPoint := TPointF.Create(x * 10, y * 10);
      LSurface.Canvas.DrawCircle(LPoint, LRadius, LDotPaint);
    end;
  end;

  FBackgroundImage := LSurface.MakeImageSnapshot;
end;

procedure TAliveGrid.StartThread;
begin
  if Assigned(FThread) then
    Exit;
  FThread := TThread.CreateAnonymousThread(ExecuteRenderLoop);
  FThread.FreeOnTerminate := True;
  FThread.Start;
end;

procedure TAliveGrid.ExecuteRenderLoop;
var
  NowTime: Cardinal;
  LW, LH: Single;
  S, i: Integer;
  LChanged: Boolean;
  R, G, B: Single;
  LMatrix: TSkColorMatrix;
  MinY: Single;
  IsDead: Boolean;
  LBlur, LShadowDown, LShadowUp, LCombinedShadow, LDotShadow: ISkImageFilter;
  LBlurPaint, LBlackPaint, LHighlightPaint, LControlDotPaint, LContentPaint: ISkPaint;
  LScrollBarPaint: ISkPaint;
  IsScrollingNow: Boolean;
begin
  LScrollBarPaint := TSkPaint.Create;
  LScrollBarPaint.AntiAlias := True;

  LBlur := TSkImageFilter.MakeBlur(12, 12, nil, TSkTileMode.Decal);
  LBlurPaint := TSkPaint.Create;
  LBlurPaint.AntiAlias := True;
  LBlurPaint.Color := TAlphaColors.White;
  LBlurPaint.ImageFilter := LBlur;

  LBlackPaint := TSkPaint.Create;
  LBlackPaint.AntiAlias := True;

  LContentPaint := TSkPaint.Create;
  LContentPaint.AntiAlias := True;

  LControlDotPaint := TSkPaint.Create;
  LControlDotPaint.AntiAlias := True;
  LDotShadow := TSkImageFilter.MakeDropShadow(0, 3, 5, 5, $99000000, nil);
  LControlDotPaint.ImageFilter := LDotShadow;

  LHighlightPaint := TSkPaint.Create;
  LHighlightPaint.AntiAlias := True;
  LHighlightPaint.ImageFilter := TSkImageFilter.MakeBlur(1.5, 1.5, nil, TSkTileMode.Decal);

  while not TThread.CheckTerminated do
  begin
    NowTime := TThread.GetTickCount;
    LChanged := False;

    IsScrollingNow := ((NowTime - FLastScrollTime < 150) and (FLastScrollTime > 0)) or FIsDraggingScrollBar;

    if FActive then
    begin
      FLock.Acquire;
      try
        LW := FCurrentWidth;
        LH := FCurrentHeight;

        if (LW > 0) and (LH > 0) then
        begin
          if FNeedsTextCacheUpdate then
            UpdateTextCache;

          // Smoothly transition colors towards target colors
          if FActualItemColor <> FTargetItemColor then
          begin
            FActualItemColor := LerpColor(FActualItemColor, FTargetItemColor, 0.05);
            for S := 0 to High(FVisibleSlides) do
              FVisibleSlides[S].IsDirty := True;
            FAnyDirty := True;
          end;
          if FActualShadowColor <> FTargetShadowColor then
          begin
            FActualShadowColor := LerpColor(FActualShadowColor, FTargetShadowColor, 0.05);
            for S := 0 to High(FVisibleSlides) do
              FVisibleSlides[S].IsDirty := True;
            FAnyDirty := True;
          end;
          if FActualDotColor <> FTargetDotColor then
          begin
            FActualDotColor := LerpColor(FActualDotColor, FTargetDotColor, 0.05);
            for S := 0 to High(FVisibleSlides) do
              FVisibleSlides[S].IsDirty := True;
            FAnyDirty := True;
          end;

          // Setup color matrix for the black/shadow paint
          R := ((FActualItemColor shr 16) and $FF) / 255.0;
          G := ((FActualItemColor shr 8) and $FF) / 255.0;
          B := (FActualItemColor and $FF) / 255.0;
          LMatrix := TSkColorMatrix.Create(0, 0, 0, 0, R, 0, 0, 0, 0, G, 0, 0, 0, 0, B, 0, 0, 0, 2.5, -0.2);
          LBlackPaint.ColorFilter := TSkColorFilter.MakeMatrix(LMatrix);

          LShadowDown := TSkImageFilter.MakeDropShadow(0, 4, 8, 8, FActualShadowColor, nil);
          LShadowUp := TSkImageFilter.MakeDropShadow(0, -2, 6, 6, FActualShadowColor, nil);
          LCombinedShadow := TSkImageFilter.MakeCompose(LShadowUp, LShadowDown);
          LBlackPaint.ImageFilter := LCombinedShadow;

          if Length(FVisibleSlides) > 0 then
          begin
            for S := 0 to High(FVisibleSlides) do
            begin
              // Removing slides get absolute priority and ignore scroll-pauses
              if FVisibleSlides[S].IsRemoving then
              begin
                ProcessSlidePhysics(FVisibleSlides[S], NowTime, LW, LH);
                ProcessSlideConstraints(FVisibleSlides[S], NowTime, LW, LH);
              end
              else if (not IsScrollingNow) or FVisibleSlides[S].IsDragging then
              begin
                ProcessSlidePhysics(FVisibleSlides[S], NowTime, LW, LH);
                ProcessSlideConstraints(FVisibleSlides[S], NowTime, LW, LH);
              end
              else
              begin
                // Fast snap particles to targets during fast scrolling without physics
                FVisibleSlides[S].CurrentX := FVisibleSlides[S].CurrentX + (FVisibleSlides[S].TargetX - FVisibleSlides[S].CurrentX) * 0.45;
                FVisibleSlides[S].CurrentY := FVisibleSlides[S].CurrentY + (FVisibleSlides[S].TargetY - FVisibleSlides[S].CurrentY) * 0.45;

                for i := 0 to High(FVisibleSlides[S].Particles) do
                begin
                  FVisibleSlides[S].Particles[i].x := FVisibleSlides[S].CurrentX + FVisibleSlides[S].Particles[i].LocalAnchorX;
                  FVisibleSlides[S].Particles[i].y := FVisibleSlides[S].CurrentY + FVisibleSlides[S].Particles[i].LocalAnchorY;
                  FVisibleSlides[S].Particles[i].OldX := FVisibleSlides[S].Particles[i].x;
                  FVisibleSlides[S].Particles[i].OldY := FVisibleSlides[S].Particles[i].y;
                  FVisibleSlides[S].Particles[i].VelX := 0;
                  FVisibleSlides[S].Particles[i].VelY := 0;
                end;

                FVisibleSlides[S].ControlDot.X := FVisibleSlides[S].Particles[FVisibleSlides[S].TopRightIdx].x + 7;
                FVisibleSlides[S].ControlDot.Y := FVisibleSlides[S].Particles[FVisibleSlides[S].TopRightIdx].y - 7;

                FVisibleSlides[S].IsDirty := True;
              end;

              // Check if removing slide is completely out of view (dead)
              if FVisibleSlides[S].IsRemoving then
              begin
                IsDead := True;
                MinY := 99999;
                for i := 0 to High(FVisibleSlides[S].Particles) do
                  if FVisibleSlides[S].Particles[i].y < MinY then
                    MinY := FVisibleSlides[S].Particles[i].y;

                if MinY <= LH + 100 then
                  IsDead := False;

                FVisibleSlides[S].IsDead := IsDead;
              end;

              // Check various conditions to mark the slide dirty for redraw
              if not FVisibleSlides[S].IsDirty then
              begin
                with FVisibleSlides[S] do
                begin
                  if Abs(CurrentX - TargetX) > 0.5 then
                    IsDirty := True;
                  if Abs(CurrentY - TargetY) > 0.5 then
                    IsDirty := True;
                  if Abs(ControlDot.ActualAlpha - ControlDot.TargetAlpha) > 0.01 then
                    IsDirty := True;
                  if Abs(ContentActualAlpha - ContentTargetAlpha) > 0.01 then
                    IsDirty := True;
                  if (Abs(ControlDot.VelX) > 0.1) or (Abs(ControlDot.VelY) > 0.1) then
                    IsDirty := True;

                  for i := 0 to High(Particles) do
                  begin
                    if (Abs(Particles[i].VelX) > 0.1) or (Abs(Particles[i].VelY) > 0.1) then
                    begin
                      IsDirty := True;
                      Break;
                    end;
                  end;

                  // Mark dirty if mouse is interacting closely
                  if FIsMouseOver and not IsDragging and not IsRemoving then
                  begin
                    if (FMousePos.X > CurrentX - 70) and (FMousePos.X < CurrentX + ActualSlideW + 70) and (FMousePos.Y > CurrentY - 70) and (FMousePos.Y < CurrentY + ActualSlideH + 70) then
                      IsDirty := True;
                  end;
                end;
              end;

              // Re-render the slide cache if dirty
              if FVisibleSlides[S].IsDirty or FVisibleSlides[S].IsRemoving then
              begin
                FAnyDirty := True;
                LChanged := True;
                ProcessSlideCaching(FVisibleSlides[S], NowTime, LW, LH, LBlurPaint, LBlackPaint, LContentPaint, LControlDotPaint, LHighlightPaint);
              end;
            end;

            // Clean up dead slides and return them to the pool
            for i := High(FVisibleSlides) downto 0 do
            begin
              if FVisibleSlides[i].IsDead then
              begin
                FVisibleSlides[i].IsRemoving := False;
                FVisibleSlides[i].IsDead := False;
                FVisibleSlides[i].LogicalItemIdx := -1;
                FVisibleSlides[i].TargetY := FCurrentHeight + 1000;
                FVisibleSlides[i].CurrentY := FVisibleSlides[i].TargetY;
                FVisibleSlides[i].ContentCache := nil;
                FVisibleSlides[i].ContentActualAlpha := 0;
                FVisibleSlides[i].ContentTargetAlpha := 0;
                FVisibleSlides[i].ControlDot.ActualAlpha := 0;
                FVisibleSlides[i].ControlDot.TargetAlpha := 0;
              end;
            end;

            UpdateSlideMapping;
          end;

          // Update scroll bar visibility and position
          if FMaxScroll > 0 then
          begin
            FScrollBarDot.X := FCurrentWidth - 15;
            FScrollBarDot.Y := BorderGap + (FScrollOffset / FMaxScroll) * (FCurrentHeight - BorderGap * 2 - ScrollBarHeight);

            if (NowTime - FLastScrollTime < 1000) or FIsDraggingScrollBar or ((FIsMouseOver) and (FMousePos.X > FCurrentWidth - 30)) then
              FScrollBarDot.TargetAlpha := 1.0
            else
              FScrollBarDot.TargetAlpha := 0.0;
          end
          else
          begin
            FScrollBarDot.TargetAlpha := 0.0;
            FScrollBarDot.Y := BorderGap;
          end;

          FScrollBarDot.ActualAlpha := FScrollBarDot.ActualAlpha + (FScrollBarDot.TargetAlpha - FScrollBarDot.ActualAlpha) * 0.05;
          if Abs(FScrollBarDot.ActualAlpha - FScrollBarDot.TargetAlpha) > 0.01 then
            FAnyDirty := True;

          if FMainImage = nil then
            FAnyDirty := True;

          // Rebuild main image if something changed
          if FAnyDirty then
          begin
            if (FMainSurface = nil) or (FMainSurfaceInfo.Width <> Round(LW)) or (FMainSurfaceInfo.Height <> Round(LH)) then
            begin
              FMainSurfaceInfo := TSkImageInfo.Create(Round(LW), Round(LH));
              FMainSurface := TSkSurface.MakeRaster(FMainSurfaceInfo);
            end;

            FMainSurface.Canvas.Clear(TAlphaColors.Null);
            if FBackgroundImage <> nil then
              FMainSurface.Canvas.DrawImage(FBackgroundImage, 0, 0);

            // Draw standard slides
            for S := 0 to High(FVisibleSlides) do
            begin
              if not FVisibleSlides[S].IsDragging then
                if FVisibleSlides[S].Cache <> nil then
                begin
                  FMainSurface.Canvas.DrawImage(FVisibleSlides[S].Cache, 0, 0);
                end;
            end;

            // Draw dragged slide last to ensure it stays on top
            if (FDraggedSlideIdx >= 0) and (FDraggedSlideIdx <= High(FVisibleSlides)) and (FVisibleSlides[FDraggedSlideIdx].Cache <> nil) then
              FMainSurface.Canvas.DrawImage(FVisibleSlides[FDraggedSlideIdx].Cache, 0, 0);

            // Draw scroll bar dot if visible
            if (FMaxScroll > 0) and (FScrollBarDot.ActualAlpha > 0.01) then
            begin
              LScrollBarPaint.Shader := nil;
              LScrollBarPaint.Color := FActualDotColor;
              LScrollBarPaint.AlphaF := FScrollBarDot.ActualAlpha;
              FMainSurface.Canvas.DrawRoundRect(TRectF.Create(FScrollBarDot.X, FScrollBarDot.Y, FScrollBarDot.X + ScrollBarWidth, FScrollBarDot.Y + ScrollBarHeight), 3, 3, LScrollBarPaint);
            end;

            FMainImage := FMainSurface.MakeImageSnapshot;
            FAnyDirty := False;
            LChanged := True;
          end;
        end;
      finally
        FLock.Release;
      end;

      if LChanged or FIsMouseOver or FIsDragging then
        SafeInvalidate;
    end;

    // Throttle thread sleep depending on activity
    if LChanged or FIsMouseOver or FIsDragging then
      Sleep(16)
    else
      Sleep(50);
  end;
end;

procedure TAliveGrid.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50);
  end;
end;

procedure TAliveGrid.SafeInvalidate;
begin
  if csDestroying in ComponentState then
    Exit;
  TThread.Queue(nil, DoRedraw);
end;

procedure TAliveGrid.DoRedraw;
begin
  if not (csDestroying in ComponentState) then
    Redraw;
end;

function TAliveGrid.GetDotRect(Idx: Integer): TRectF;
begin
  if (Idx < 0) or (Idx > High(FVisibleSlides)) then
    Exit(TRectF.Empty);

  with FVisibleSlides[Idx] do
    Result := TRectF.Create(ControlDot.X - 9, ControlDot.Y - 9, ControlDot.X + 9, ControlDot.Y + 9);
end;

procedure TAliveGrid.Resize;
var
  i, j, RequiredCols: Integer;
  SpaceX, SpaceY: Single;
begin
  inherited;
  FLock.Acquire;
  try
    FCurrentWidth := Width;
    FCurrentHeight := Height;
    if (FCurrentWidth > 0) and (FCurrentHeight > 0) then
    begin
      FIsResizing := True;
      UpdateVisibleSlides;

      if (FLastWidth <> Round(FCurrentWidth)) or (FLastHeight <> Round(FCurrentHeight)) then
      begin
        FLastWidth := Round(FCurrentWidth);
        FLastHeight := Round(FCurrentHeight);
        DrawBackgroundCache;
        FNeedsTextCacheUpdate := True;
      end;

      if FNeedsTextCacheUpdate then
        UpdateTextCache;

      // Adjust internal particle grid for all visible slides on resize
      for i := 0 to High(FVisibleSlides) do
      begin
        FVisibleSlides[i].ActualSlideW := FCurrentWidth - (BorderGap * 2);
        FVisibleSlides[i].ActualSlideH := BaseSlideH;

        RequiredCols := Max(10, Round(FVisibleSlides[i].ActualSlideW / MinSpaceX));
        if FVisibleSlides[i].Cols <> RequiredCols then
        begin
          FVisibleSlides[i].Cols := RequiredCols;
          SetLength(FVisibleSlides[i].Particles, FVisibleSlides[i].Cols * SlideRows);
          FVisibleSlides[i].TopRightIdx := (FVisibleSlides[i].Cols - 1) * SlideRows;
        end;

        SpaceX := FVisibleSlides[i].ActualSlideW / (FVisibleSlides[i].Cols - 1);
        SpaceY := FVisibleSlides[i].ActualSlideH / (SlideRows - 1);
        FVisibleSlides[i].RestX := SpaceX;
        FVisibleSlides[i].RestY := SpaceY;
        FVisibleSlides[i].RestDiag := Sqrt(SpaceX * SpaceX + SpaceY * SpaceY);

        for j := 0 to High(FVisibleSlides[i].Particles) do
        begin
          FVisibleSlides[i].Particles[j].LocalAnchorX := (j div SlideRows) * SpaceX;
          FVisibleSlides[i].Particles[j].LocalAnchorY := (j mod SlideRows) * SpaceY;
          FVisibleSlides[i].Particles[j].x := FVisibleSlides[i].CurrentX + FVisibleSlides[i].Particles[j].LocalAnchorX;
          FVisibleSlides[i].Particles[j].y := FVisibleSlides[i].CurrentY + FVisibleSlides[i].Particles[j].LocalAnchorY;
          FVisibleSlides[i].Particles[j].OldX := FVisibleSlides[i].Particles[j].x;
          FVisibleSlides[i].Particles[j].OldY := FVisibleSlides[i].Particles[j].y;
          FVisibleSlides[i].Particles[j].VelX := 0;
          FVisibleSlides[i].Particles[j].VelY := 0;
        end;

        if not FVisibleSlides[i].IsDragging then
          UpdateTargets;

        FVisibleSlides[i].IsDirty := True;
      end;

      if (FMainSurface = nil) or (FMainSurfaceInfo.Width <> FLastWidth) or (FMainSurfaceInfo.Height <> FLastHeight) then
      begin
        FMainSurfaceInfo := TSkImageInfo.Create(FLastWidth, FLastHeight);
        FMainSurface := TSkSurface.MakeRaster(FMainSurfaceInfo);
      end;

      if FMainImage = nil then
        FMainSurface.Canvas.Clear(TAlphaColors.Black)
      else
        FMainSurface.Canvas.Clear(TAlphaColors.Null);

      if FBackgroundImage <> nil then
        FMainSurface.Canvas.DrawImage(FBackgroundImage, 0, 0);

      for i := 0 to High(FVisibleSlides) do
      begin
        if FVisibleSlides[i].Cache <> nil then
          FMainSurface.Canvas.DrawImage(FVisibleSlides[i].Cache, 0, 0);
      end;

      FMainImage := FMainSurface.MakeImageSnapshot;
      FAnyDirty := True;
    end;
  finally
    FLock.Release;
  end;
  Redraw;

  if not FMouseIsDown then
  begin
    FIsResizing := False;
    FAnyDirty := True;
  end;
end;

procedure TAliveGrid.MouseDown(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single);
var
  i: Integer;
  LDotRect: TRectF;
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    FMouseIsDown := True;
    FMouseDownPos := TPointF.Create(X, Y);
    FMouseDownSlideIdx := -1;
    FMouseIsDownOnDot := False;

    // Check scroll bar interaction first
    if (FMaxScroll > 0) and (X >= FScrollBarDot.X - 5) and (X <= FScrollBarDot.X + ScrollBarWidth + 5) and (Y >= FScrollBarDot.Y - 5) and (Y <= FScrollBarDot.Y + ScrollBarHeight + 5) then
    begin
      FIsDraggingScrollBar := True;
      Exit;
    end;

    FLock.Acquire;
    try
      // Hit test for slides and control dots
      for i := 0 to High(FVisibleSlides) do
      begin
        if not FVisibleSlides[i].IsRemoving and (X >= FVisibleSlides[i].CurrentX) and (X <= FVisibleSlides[i].CurrentX + FVisibleSlides[i].ActualSlideW) and (Y >= FVisibleSlides[i].CurrentY) and (Y <= FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH) then
        begin
          FMouseDownSlideIdx := i;
          LDotRect := GetDotRect(i);
          if LDotRect.Contains(TPointF.Create(X, Y)) then
            FMouseIsDownOnDot := True;

          FDraggedSlideIdx := i;
          FDragOffsetX := X - FVisibleSlides[i].CurrentX;
          FDragOffsetY := Y - FVisibleSlides[i].CurrentY;

          if FMouseIsDownOnDot then
          begin
            if Assigned(FOnDotMouseDown) then
              FOnDotMouseDown(Self, i, Button, ButtonState, X, Y);
          end
          else
          begin
            if Assigned(FOnSlideMouseDown) then
              FOnSlideMouseDown(Self, i, Button, ButtonState, X, Y);
          end;
          Break;
        end;
      end;
    finally
      FLock.Release;
    end;
  end;
end;

procedure TAliveGrid.MouseMove(Shift: TShiftState; X, Y: Single);
var
  i, DraggedLogical, TargetLogical: Integer;
  DraggedY, TargetCenterY: Single;
begin
  inherited;
  FMousePos := TPointF.Create(X, Y);
  FIsMouseOver := True;

  // Handle scrollbar dragging
  if FIsDraggingScrollBar and (FMaxScroll > 0) then
  begin
    FLock.Acquire;
    try
      if (FCurrentHeight - BorderGap * 2 - ScrollBarHeight) > 0 then
      begin
        FScrollOffset := EnsureRange(((Y - BorderGap) / (FCurrentHeight - BorderGap * 2 - ScrollBarHeight)) * FMaxScroll, 0, FMaxScroll);
        FLastScrollTime := TThread.GetTickCount;
        UpdateSlideMapping;
        UpdateTargets;
      end;
    finally
      FLock.Release;
    end;
    Redraw;
    Exit;
  end;

  // Handle slide dragging and swapping
  if FMouseIsDown and (FDraggedSlideIdx <> -1) then
  begin
    if not FIsDragging then
    begin
      // Only start dragging if moved sufficiently to avoid accidental drags on clicks
      if Sqrt(Sqr(X - FMouseDownPos.X) + Sqr(Y - FMouseDownPos.Y)) > 20 then
      begin
        FIsDragging := True;
        FLock.Acquire;
        try
          if FDraggedSlideIdx <= High(FVisibleSlides) then
          begin
            FVisibleSlides[FDraggedSlideIdx].IsDragging := True;
            FVisibleSlides[FDraggedSlideIdx].IsDirty := True;
            FAnyDirty := True;
          end;
        finally
          FLock.Release;
        end;
      end;
    end;

    if FIsDragging and (FDraggedSlideIdx <= High(FVisibleSlides)) then
    begin
      FLock.Acquire;
      try
        FVisibleSlides[FDraggedSlideIdx].DragTargetX := X - FDragOffsetX;
        FVisibleSlides[FDraggedSlideIdx].DragTargetY := Y - FDragOffsetY;
        FVisibleSlides[FDraggedSlideIdx].IsDirty := True;
        FAnyDirty := True;

        // Determine if dragged slide overlaps with others to swap items
        for i := 0 to High(FVisibleSlides) do
        begin
          if (i = FDraggedSlideIdx) or FVisibleSlides[i].IsRemoving or (FVisibleSlides[i].LogicalItemIdx < 0) then
            Continue;

          DraggedLogical := FVisibleSlides[FDraggedSlideIdx].LogicalItemIdx;
          TargetLogical := FVisibleSlides[i].LogicalItemIdx;

          DraggedY := FVisibleSlides[FDraggedSlideIdx].CurrentY + FVisibleSlides[FDraggedSlideIdx].ActualSlideH / 2;
          TargetCenterY := FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH / 2;

          if (DraggedY > TargetCenterY) and (DraggedLogical < TargetLogical) then
          begin
            SwapDataItems(DraggedLogical, TargetLogical);
            FVisibleSlides[FDraggedSlideIdx].LogicalItemIdx := TargetLogical;
            FVisibleSlides[i].LogicalItemIdx := DraggedLogical;
            UpdateTargets;
          end
          else if (DraggedY < TargetCenterY) and (DraggedLogical > TargetLogical) then
          begin
            SwapDataItems(DraggedLogical, TargetLogical);
            FVisibleSlides[FDraggedSlideIdx].LogicalItemIdx := TargetLogical;
            FVisibleSlides[i].LogicalItemIdx := DraggedLogical;
            UpdateTargets;
          end;
        end;
      finally
        FLock.Release;
      end;
    end;
  end;
  Redraw;
end;

procedure TAliveGrid.MouseUp(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single);
begin
  inherited;
  FMouseIsDown := False;

  if FIsDraggingScrollBar then
  begin
    FIsDraggingScrollBar := False;
    Exit;
  end;

  // Release dragged slide
  if FDraggedSlideIdx <> -1 then
  begin
    FLock.Acquire;
    try
      if FDraggedSlideIdx <= High(FVisibleSlides) then
      begin
        FVisibleSlides[FDraggedSlideIdx].IsDragging := False;
        FVisibleSlides[FDraggedSlideIdx].IsDirty := True;
      end;
      FAnyDirty := True;
      UpdateTargets;
    finally
      FLock.Release;
    end;
  end;

  // Trigger click events if no dragging occurred
  if (not FIsDragging) and (FMouseDownSlideIdx <> -1) then
  begin
    if FMouseIsDownOnDot then
    begin
      if Assigned(FOnDotClick) then
        FOnDotClick(Self, FMouseDownSlideIdx);
    end
    else
    begin
      if Assigned(FOnSlideClick) then
        FOnSlideClick(Self, FMouseDownSlideIdx);
    end;
  end;

  FIsDragging := False;
  FDraggedSlideIdx := -1;
  FMouseDownSlideIdx := -1;
end;

procedure TAliveGrid.DblClick;
var
  i: Integer;
  LLocalPos: TPointF;
begin
  inherited;
  LLocalPos := FMousePos;

  // Fire double click events depending on whether dot or slide was hit
  for i := 0 to High(FVisibleSlides) do
  begin
    if not FVisibleSlides[i].IsRemoving and (LLocalPos.X >= FVisibleSlides[i].CurrentX) and (LLocalPos.X <= FVisibleSlides[i].CurrentX + FVisibleSlides[i].ActualSlideW) and (LLocalPos.Y >= FVisibleSlides[i].CurrentY) and (LLocalPos.Y <= FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH) then
    begin
      if GetDotRect(i).Contains(LLocalPos) then
      begin
        if Assigned(FOnDotDblClick) then
          FOnDotDblClick(Self, i);
      end
      else
      begin
        if Assigned(FOnSlideDblClick) then
          FOnSlideDblClick(Self, i);
      end;
      Break;
    end;
  end;
end;

procedure TAliveGrid.DoMouseLeave;
begin
  inherited;
  FIsMouseOver := False;
  FAnyDirty := True;
  Redraw;
end;

procedure TAliveGrid.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
begin
  if FMainImage <> nil then
    ACanvas.DrawImage(FMainImage, 0, 0, nil)
  else
    ACanvas.Clear(TAlphaColors.Black);
end;

procedure TAliveGrid.MouseWheel(Shift: TShiftState; WheelDelta: Integer; var Handled: Boolean);
begin
  inherited;
  Handled := True;
  if FMaxScroll > 0 then
  begin
    FLock.Acquire;
    try
      FScrollOffset := EnsureRange(FScrollOffset - (WheelDelta * 1.0), 0, FMaxScroll);
      FLastScrollTime := TThread.GetTickCount;
      UpdateSlideMapping;
      UpdateTargets;
    finally
      FLock.Release;
    end;
    Redraw;
  end;
end;

end.

