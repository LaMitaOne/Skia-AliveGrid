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
*******************************************************************************}

unit uAliveGrid;

interface

uses
  System.SysUtils, System.Types, System.Classes, System.Math, System.SyncObjs,
  System.UITypes, FMX.Types, FMX.Controls, FMX.Graphics, FMX.Skia, System.Skia;

type
  /// <summary>
  /// Holds the static data for a grid item, including text, paths, and image bitmap.
  /// </summary>
  TGridItemData = record
    Caption: string;
    Hint: string;
    FilePath: string;
    ImagePath: string;
    BaseColor: TAlphaColor;
    ImageBitmap: ISkImage;
  end;

  /// <summary>
  /// Represents a single particle node within the liquid slide grid.
  /// Used in the physics calculation (Verlet integration).
  /// </summary>
  TGridParticle = record
    X, Y: Single;
    OldX, OldY: Single;
    VelX, VelY: Single;
    LocalAnchorX, LocalAnchorY: Single;
    ActivationTime: Cardinal;
  end;

  /// <summary>
  /// Represents the interactive magnetic dot at the top-right of each slide.
  /// </summary>
  TControlDot = record
    X, Y: Single;
    OldX, OldY: Single;
    VelX, VelY: Single;
    LocalAnchorX, LocalAnchorY: Single;
    ActivationTime: Cardinal;
    ActualAlpha, TargetAlpha: Single;
  end;

  /// <summary>
  /// The main visual slide object. Contains its own physics state, content cache,
  /// and rendering surface to allow independent updates.
  /// </summary>
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

    // Caching Properties
    Cache: ISkImage;
    SlideSurface: ISkSurface;
    SlideSurfaceInfo: TSkImageInfo;
    ContentCache: ISkImage;
    ContentActualAlpha: Single;
    ContentTargetAlpha: Single;

    TopRightIdx: Integer;
    ActualSlideW, ActualSlideH: Single;
    ItemID: Integer;
  end;

  TSlideMouseEvent = procedure(Sender: TObject; SlideIdx: Integer; Button: TMouseButton; Shift: TShiftState; X, Y: Single) of object;

  TSlideNotifyEvent = procedure(Sender: TObject; SlideIdx: Integer) of object;

  /// <summary>
  /// A liquid, particle-based grid container component.
  /// Renders dynamically using Skia in a background thread.
  /// </summary>
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

    // Drag & Drop State
    FDraggedSlideIdx: Integer;
    FDragOffsetX, FDragOffsetY: Single;
    FIsDragging: Boolean;
    FMouseDownPos: TPointF;
    FMouseIsDown: Boolean;
    FMouseDownSlideIdx: Integer;
    FMouseIsDownOnDot: Boolean;
    FNextItemID: Integer;

    // Target and Actual Colors (for smooth lerping transitions)
    FTargetItemColor, FActualItemColor: TAlphaColor;
    FTargetShadowColor, FActualShadowColor: TAlphaColor;
    FTargetDotColor, FActualDotColor: TAlphaColor;

    // Data Arrays
    FAllItems: array of TGridItemData;
    FAllItemIDs: array of Integer;
    FVisibleSlides: array of TGridSlide;

    // Font & Text Cache
    FFontName: string;
    FFontSize: Single;
    FFontIsBold: Boolean;
    FFontIsItalic: Boolean;
    FCaptionColor, FPathColor: TAlphaColor;
    FTextCache: ISkImage;
    FTextCacheSurface: ISkSurface;
    FTextCacheInfo: TSkImageInfo;
    FNeedsTextCacheUpdate: Boolean;

    // Events
    FOnSlideMouseDown: TSlideMouseEvent;
    FOnDotMouseDown: TSlideMouseEvent;
    FOnSlideClick: TSlideNotifyEvent;
    FOnSlideDblClick: TSlideNotifyEvent;
    FOnDotClick: TSlideNotifyEvent;
    FOnDotDblClick: TSlideNotifyEvent;

    { Setters for properties }
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

    { Thread and Rendering Management }
    procedure SafeInvalidate;
    procedure DoRedraw;
    procedure StartThread;
    procedure StopThread;
    procedure DrawBackgroundCache;
    procedure UpdateTextCache;

    { Slide Management & Physics }
    procedure UpdateVisibleSlides;
    procedure SpawnVisibleSlide(ActiveIdx: Integer);
    procedure UpdateTargets;
    procedure SwapSlides(Idx1, Idx2: Integer);
    procedure GenerateContentCache(var ASlide: TGridSlide; const AData: TGridItemData);
    procedure ProcessSlidePhysics(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
    procedure ProcessSlideConstraints(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single);
    procedure ProcessSlideCaching(var ASlide: TGridSlide; const NowTime: Cardinal; const LW, LH: Single; const ABlurPaint, ABlackPaint, AContentPaint, AControlDotPaint, AHighlightPaint: ISkPaint);
    procedure ExecuteRenderLoop;

    { Utilities }
    function GetDotRect(Idx: Integer): TRectF;
    function FindItemIdxByID(ID: Integer): Integer;
  protected
    procedure Resize; override;
    procedure Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
    procedure MouseDown(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single); override;
    procedure MouseUp(Button: TMouseButton; ButtonState: TShiftState; X, Y: Single); override;
    procedure DoMouseLeave; override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    /// <summary>
    /// Adds a new item to the grid. Generates a thumbnail if an image path is provided.
    /// </summary>
    procedure AddItem(const ACaption: string = ''; const AHint: string = ''; const AFilePath: string = ''; const AImagePath: string = '');

    /// <summary>
    /// Marks an item for removal. The slide will play a death animation before being destroyed.
    /// </summary>
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

/// <summary>
/// Helper function to interpolate linearly between two TAlphaColors.
/// Used for smooth color transitions (Actual to Target).
/// </summary>
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
  Result := (Round(A1 + (A2 - A1) * t) shl 24) or (Round(R1 + (R2 - R1) * t) shl 16) or (Round(G1 + (G2 - G1) * t) shl 8) or (Round(B1 + (B2 - B1) * t));
end;

{ TAliveGrid }

constructor TAliveGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Initialize thread synchronization
  FLock := TCriticalSection.Create;
  HitTest := True;

  // Default states
  FActive := True;
  FIntensity := 0.2;
  FIsMouseOver := False;
  FCurrentWidth := 100;
  FCurrentHeight := 100;
  FMousePos := TPointF.Create(0, 0);

  // Drag state initialization
  FDraggedSlideIdx := -1;
  FIsDragging := False;
  FMouseIsDown := False;
  FIsResizing := False;
  FMouseDownSlideIdx := -1;
  FNextItemID := 1;

  // Default Colors
  FTargetItemColor := $FF080A12;
  FActualItemColor := FTargetItemColor;
  FTargetShadowColor := $FF000000;
  FActualShadowColor := FTargetShadowColor;
  FTargetDotColor := $FF00838F;
  FActualDotColor := FTargetDotColor;

  // Default Font
  FFontName := 'Segoe UI';
  FFontSize := 18;
  FFontIsBold := False;
  FFontIsItalic := False;

  FCaptionColor := TAlphaColors.White;
  FPathColor := $FF888888;

  FNeedsTextCacheUpdate := True;

  // Start the background rendering thread
  StartThread;
end;

destructor TAliveGrid.Destroy;
begin
  // Ensure thread is safely terminated before freeing the lock
  StopThread;
  FreeAndNil(FLock);
  inherited;
end;

/// <summary>
/// Finds the array index of an item by its unique persistent ID.
/// Crucial for maintaining mapping when items are inserted or removed.
/// </summary>
function TAliveGrid.FindItemIdxByID(ID: Integer): Integer;
begin
  for Result := 0 to High(FAllItemIDs) do
    if FAllItemIDs[Result] = ID then
      Exit;
  Result := -1;
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

{ Property Setters: Update targets and flag caches as dirty to force a redraw }

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
  LIdx: Integer;
  LOrigImg: ISkImage;
  LThumbSurface: ISkSurface;
  LScale, LOffX, LOffY: Single;
begin
  FLock.Acquire;
  try
    LIdx := Length(FAllItems);
    SetLength(FAllItems, LIdx + 1);
    SetLength(FAllItemIDs, LIdx + 1);

    // Set default caption if empty
    if ACaption = '' then
      FAllItems[LIdx].Caption := 'Item ' + IntToStr(LIdx + 1)
    else
      FAllItems[LIdx].Caption := ACaption;

    FAllItems[LIdx].Hint := AHint;
    FAllItems[LIdx].FilePath := AFilePath;
    FAllItems[LIdx].ImagePath := AImagePath;

    // Assign a rotating base color for items without images
    FAllItems[LIdx].BaseColor := Colors[LIdx mod Length(Colors)];
    FAllItems[LIdx].ImageBitmap := nil;

    // Process Image: Load, scale, and apply Letterbox (KeepAspect)
    if (AImagePath <> '') and FileExists(AImagePath) then
    begin
      try
        LOrigImg := TSkImage.MakeFromEncodedFile(AImagePath);
        LThumbSurface := TSkSurface.MakeRaster(TSkImageInfo.Create(BaseSlideH, BaseSlideH));
        LThumbSurface.Canvas.Clear(TAlphaColors.Null);

        // Calculate Letterbox scaling: Fit image inside BaseSlideH bounds
        LScale := Min(BaseSlideH / LOrigImg.Width, BaseSlideH / LOrigImg.Height);
        LOffX := (BaseSlideH - LOrigImg.Width * LScale) / 2;
        LOffY := (BaseSlideH - LOrigImg.Height * LScale) / 2;

        // Draw image centered onto the thumbnail surface
        LThumbSurface.Canvas.DrawImageRect(LOrigImg, TRectF.Create(0, 0, LOrigImg.Width, LOrigImg.Height), TRectF.Create(LOffX, LOffY, LOffX + LOrigImg.Width * LScale, LOffY + LOrigImg.Height * LScale), TSkSamplingOptions.Medium, nil);
        FAllItems[LIdx].ImageBitmap := LThumbSurface.MakeImageSnapshot;
      except
        FAllItems[LIdx].ImageBitmap := nil;
      end;
    end;

    // Assign Unique ID and increment counter
    FAllItemIDs[LIdx] := FNextItemID;
    Inc(FNextItemID);

    FNeedsTextCacheUpdate := True;
    UpdateVisibleSlides;
  finally
    FLock.Release;
  end;
end;

procedure TAliveGrid.RemoveItem(Index: Integer);
begin
  FLock.Acquire;
  try
    // Remove from data arrays
    if (Index >= 0) and (Index <= High(FAllItems)) then
    begin
      System.Delete(FAllItems, Index, 1);
      System.Delete(FAllItemIDs, Index, 1);
    end;

    // Trigger despawn animation if the slide is currently visible
    if (Index >= 0) and (Index <= High(FVisibleSlides)) then
    begin
      if not FVisibleSlides[Index].IsRemoving then
      begin
        FVisibleSlides[Index].IsRemoving := True;
        FVisibleSlides[Index].IsDirty := True;
        FVisibleSlides[Index].ContentCache := nil;
        FVisibleSlides[Index].ContentTargetAlpha := 0;
        FVisibleSlides[Index].ContentActualAlpha := 0;
        FVisibleSlides[Index].ControlDot.TargetAlpha := 0;
        FAnyDirty := True;
      end;
    end;

    FNeedsTextCacheUpdate := True;
    UpdateVisibleSlides;
  finally
    FLock.Release;
  end;
end;

/// <summary>
/// Determines how many slides can fit in the current control height and
/// spawns or despawns slides accordingly.
/// </summary>
procedure TAliveGrid.UpdateVisibleSlides;
var
  MaxVisible, i, ActiveCount: Integer;
begin
  if FCurrentHeight <= BorderGap + BaseSlideH then
    MaxVisible := 0
  else
    MaxVisible := Floor((FCurrentHeight - BorderGap - BaseSlideH) / (BaseSlideH + SlideGap)) + 1;

  if Length(FAllItems) < MaxVisible then
    MaxVisible := Length(FAllItems);

  ActiveCount := 0;
  for i := 0 to High(FVisibleSlides) do
    if not FVisibleSlides[i].IsRemoving then
      Inc(ActiveCount);

  // Spawn new slides if we have more items than visible slides
  while (ActiveCount < MaxVisible) and (Length(FAllItems) > ActiveCount) do
  begin
    SpawnVisibleSlide(ActiveCount);
    Inc(ActiveCount);
    FAnyDirty := True;
  end;

  ActiveCount := 0;
  for i := 0 to High(FVisibleSlides) do
    if not FVisibleSlides[i].IsRemoving then
      Inc(ActiveCount);

  // Despawn excess slides if control shrunk
  if ActiveCount > MaxVisible then
  begin
    for i := High(FVisibleSlides) downto 0 do
    begin
      if ActiveCount <= MaxVisible then
        Break;
      if not FVisibleSlides[i].IsRemoving then
      begin
        FVisibleSlides[i].IsRemoving := True;
        FVisibleSlides[i].IsDirty := True;
        FVisibleSlides[i].ContentCache := nil;
        FVisibleSlides[i].ContentTargetAlpha := 0;
        FVisibleSlides[i].ContentActualAlpha := 0;
        FVisibleSlides[i].ControlDot.TargetAlpha := 0;
        FAnyDirty := True;
        Dec(ActiveCount);
      end;
    end;
  end;

  UpdateTargets;
end;

/// <summary>
/// Updates the TargetX/TargetY coordinates for all visible slides based on their index.
/// </summary>
procedure TAliveGrid.UpdateTargets;
var
  i, ActiveIdx: Integer;
begin
  ActiveIdx := 0;
  for i := 0 to High(FVisibleSlides) do
  begin
    if not FVisibleSlides[i].IsRemoving then
    begin
      FVisibleSlides[i].ActualSlideW := FCurrentWidth - (BorderGap * 2);
      FVisibleSlides[i].ActualSlideH := BaseSlideH;

      if not FVisibleSlides[i].IsDragging then
      begin
        FVisibleSlides[i].TargetX := BorderGap;
        FVisibleSlides[i].TargetY := BorderGap + (ActiveIdx * (BaseSlideH + SlideGap));
      end;
      Inc(ActiveIdx);
      FVisibleSlides[i].IsDirty := True;
      FAnyDirty := True;
    end;
  end;
end;

/// <summary>
/// Swaps two slides in the visible array (used for Drag & Drop reordering).
/// </summary>
procedure TAliveGrid.SwapSlides(Idx1, Idx2: Integer);
var
  TempSlide: TGridSlide;
begin
  if (Idx1 < 0) or (Idx1 > High(FVisibleSlides)) or (Idx2 < 0) or (Idx2 > High(FVisibleSlides)) then
    Exit;

  TempSlide := FVisibleSlides[Idx1];
  FVisibleSlides[Idx1] := FVisibleSlides[Idx2];
  FVisibleSlides[Idx2] := TempSlide;
end;

/// <summary>
/// Initializes a new slide and generates its particle grid.
/// </summary>
procedure TAliveGrid.SpawnVisibleSlide(ActiveIdx: Integer);
var
  LIdx, i, j: Integer;
  SpaceX, SpaceY, StartX, StartY: Single;
  BaseTime: Cardinal;
  RequiredCols: Integer;
begin
  LIdx := Length(FVisibleSlides);
  SetLength(FVisibleSlides, LIdx + 1);

  with FVisibleSlides[LIdx] do
  begin
    ActualSlideW := FCurrentWidth - (BorderGap * 2);
    ActualSlideH := BaseSlideH;

    // Calculate particle grid density based on slide width
    RequiredCols := Max(10, Round(ActualSlideW / MinSpaceX));
    Cols := RequiredCols;
    Rows := SlideRows;

    SetLength(Particles, Cols * Rows);
    IsRemoving := False;
    IsDead := False;
    IsDirty := True;
    IsDragging := False;
    Cache := nil;
    SlideSurface := nil;
    TopRightIdx := (Cols - 1) * Rows; // Bottom-right index used for ControlDot anchor

    // Map this slide to the data item via unique ID
    ItemID := FAllItemIDs[ActiveIdx];

    if FNeedsTextCacheUpdate then
      UpdateTextCache;

    // Generate the static content (image/text) cache
    GenerateContentCache(FVisibleSlides[LIdx], FAllItems[ActiveIdx]);
    ContentActualAlpha := 0;
    ContentTargetAlpha := 0;

    // Calculate resting distances between particles for constraints
    SpaceX := ActualSlideW / (Cols - 1);
    SpaceY := ActualSlideH / (Rows - 1);
    RestX := SpaceX;
    RestY := SpaceY;
    RestDiag := Sqrt(SpaceX * SpaceX + SpaceY * SpaceY);

    // Target position on screen
    TargetX := BorderGap;
    TargetY := BorderGap + (ActiveIdx * (BaseSlideH + SlideGap));
    CurrentX := TargetX;
    CurrentY := TargetY;

    // Spawn animation starting point (off-screen bottom-center)
    StartX := FCurrentWidth / 2;
    StartY := FCurrentHeight + 50;
    BaseTime := TThread.GetTickCount;

    // Initialize Magnetic Control Dot
    ControlDot.LocalAnchorX := ActualSlideW - 21;
    ControlDot.LocalAnchorY := 21;
    ControlDot.X := CurrentX + ControlDot.LocalAnchorX;
    ControlDot.Y := CurrentY + ControlDot.LocalAnchorY;
    ControlDot.OldX := ControlDot.X;
    ControlDot.OldY := ControlDot.Y;
    ControlDot.VelX := 0;
    ControlDot.VelY := 0;
    ControlDot.ActivationTime := BaseTime + 1200; // Delay before dot appears
    ControlDot.ActualAlpha := 0;
    ControlDot.TargetAlpha := 0;

    MaxActivationTime := 0;

    // Initialize Particles
    for i := 0 to Cols - 1 do
    begin
      for j := 0 to Rows - 1 do
      begin
        Particles[i * Rows + j].LocalAnchorX := i * SpaceX;
        Particles[i * Rows + j].LocalAnchorY := j * SpaceY;

        // Stagger spawn positions slightly for a waterfall effect
        Particles[i * Rows + j].X := StartX + (i * 2) - 10;
        Particles[i * Rows + j].Y := StartY + (i * 4) + (j * 15);
        Particles[i * Rows + j].OldX := Particles[i * Rows + j].X;
        Particles[i * Rows + j].OldY := Particles[i * Rows + j].Y;
        Particles[i].VelX := 0;
        Particles[i].VelY := -15; // Initial upward velocity

        // Stagger activation times so particles "fly" into place sequentially
        Particles[i * Rows + j].ActivationTime := BaseTime + Cardinal(i * 60);
        if Particles[i * Rows + j].ActivationTime > MaxActivationTime then
          MaxActivationTime := Particles[i * Rows + j].ActivationTime;
      end;
    end;
    MaxActivationTime := MaxActivationTime + 500;
  end;
end;

/// <summary>
/// Renders all text into a single large texture (FTextCache).
/// This prevents text cropping and allows fast drawing by slicing the texture per slide.
/// </summary>
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

  // Determine font style
  LSkStyle := TSkFontStyle.Normal;
  if FFontIsBold then
    LSkStyle := TSkFontStyle.Bold;
  if FFontIsItalic then
    LSkStyle := TSkFontStyle.Italic;

  LTypeface := TSkTypeface.MakeFromName(FFontName, LSkStyle);
  LFont := TSkFont.Create(LTypeface, FFontSize);
  LTinyFont := TSkFont.Create(LTypeface, 10); // Smaller font for file paths

  // Create a surface tall enough to hold all items' text stacked vertically
  FTextCacheInfo := TSkImageInfo.Create(Round(FCurrentWidth), LCount * BaseSlideH);
  FTextCacheSurface := TSkSurface.MakeRaster(FTextCacheInfo);
  FTextCacheSurface.Canvas.Clear(TAlphaColors.Null);

  LPaint := TSkPaint.Create;
  LPaint.AntiAlias := True;

  // Draw all text entries
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

/// <summary>
/// Draws the static content (Image/Square + Text) of a slide into a cache.
/// Also applies gradient fading to the edges of the image to blend it into the fluid shape.
/// </summary>
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

  // 1. Draw left colored square or image thumbnail (100x100)
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

  // 2. Draw Text by slicing the global FTextCache based on ItemID mapping
  if (ItemIdx <> -1) and (FTextCache <> nil) then
  begin
    LSurface.Canvas.DrawImageRect(FTextCache, TRectF.Create(0, ItemIdx * BaseSlideH, ASlide.ActualSlideW, (ItemIdx + 1) * BaseSlideH), TRectF.Create(0, 0, ASlide.ActualSlideW, BaseSlideH), TSkSamplingOptions.Medium, LPaint);
  end;

  // 3. Gradient Fade on the 4 edges of the image ONLY to blend smoothly into the blob
  LPaint.Color := FadeColor;

  // Top edge fade
  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, 0), TPointF.Create(0, 15), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, 0, BaseSlideH, 15), LPaint);

  // Bottom edge fade
  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, BaseSlideH), TPointF.Create(0, BaseSlideH - 15), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, BaseSlideH - 15, BaseSlideH, BaseSlideH), LPaint);

  // Left edge fade
  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(0, 0), TPointF.Create(15, 0), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(0, 0, 15, BaseSlideH), LPaint);

  // Right edge fade
  LPaint.Shader := TSkShader.MakeGradientLinear(TPointF.Create(BaseSlideH, 0), TPointF.Create(BaseSlideH - 15, 0), FadeColor, TAlphaColors.Null, TSkTileMode.Clamp);
  LSurface.Canvas.DrawRect(TRectF.Create(BaseSlideH - 15, 0, BaseSlideH, BaseSlideH), LPaint);

  ASlide.ContentCache := LSurface.MakeImageSnapshot;
end;

/// <summary>
/// Updates particle velocities and positions based on Verlet integration.
/// Handles mouse interaction (repulsion) and drag logic.
/// </summary>
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
        // If dragging, snap instantly to drag target
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
      if FIsMouseOver and not IsDragging then
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

      // Clamp velocities to prevent explosions
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

/// <summary>
/// Enforces structural integrity by applying distance constraints between particles.
/// Runs multiple iterations to approximate a rigid/springy grid.
/// </summary>
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
          // Fly towards bottom center when dying
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

/// <summary>
/// Renders the slide into its individual cache surface.
/// Draws fluid shape, shadow, content texture, and control dot.
/// </summary>
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
  LIsSnapping: Boolean;
begin
  with ASlide do
  begin
    // --- Sync ControlDot position to the top-right particle ---
    LTargetX := Particles[TopRightIdx].X + 7;
    LTargetY := Particles[TopRightIdx].Y - 7;

    // ControlDot Magnetic Snap to Mouse
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

    // Trigger fade-in animation when spawn time is reached
    if (NowTime > ControlDot.ActivationTime) and (ControlDot.TargetAlpha < 1.0) and not FIsResizing then
    begin
      ControlDot.TargetAlpha := 1.0;
      ContentTargetAlpha := 1.0;
    end;

    // Interpolate Alphas
    ControlDot.ActualAlpha := ControlDot.ActualAlpha + (ControlDot.TargetAlpha - ControlDot.ActualAlpha) * 0.05;
    ContentActualAlpha := ContentActualAlpha + (ContentTargetAlpha - ContentActualAlpha) * 0.05;

    // --- Initialize Slide Surface if needed ---
    if (SlideSurface = nil) or (SlideSurfaceInfo.Width <> Round(LW)) or (SlideSurfaceInfo.Height <> Round(LH)) then
    begin
      SlideSurfaceInfo := TSkImageInfo.Create(Round(LW), Round(LH));
      SlideSurface := TSkSurface.MakeRaster(SlideSurfaceInfo);
    end;

    SlideSurface.Canvas.Clear(TAlphaColors.Null);

    // Build Fluid Path from particles
    LBuilder := TSkPathBuilder.Create;
    LBuilder.FillType := TSkPathFillType.Winding;
    for i := 0 to High(Particles) do
      LBuilder.AddCircle(Particles[i].X, Particles[i].Y, ParticleRadius);
    LPath := LBuilder.Detach;

    // 1. Draw Fluid Shape with Blur (creates the blob outline)
    SlideSurface.Canvas.DrawPath(LPath, ABlurPaint);
    TempImg := SlideSurface.MakeImageSnapshot;

    SlideSurface.Canvas.Clear(TAlphaColors.Null);
    // Draw the blurred shape back with shadow and color filters
    SlideSurface.Canvas.DrawImage(TempImg, 0, 0, ABlackPaint);

    // 2. Draw Content Texture (Text + Image)
    ContentAlpha := ContentActualAlpha;
    if (ContentAlpha > 0.01) and (ContentCache <> nil) then
    begin
      AContentPaint.AlphaF := ContentAlpha;
      LIsSnapping := (Abs(CurrentX - TargetX) > 0.5) or (Abs(CurrentY - TargetY) > 0.5);

      // If dragging or snapping, bind content to particle[0] so it flows with the jelly motion
      if IsDragging or LIsSnapping then
        SlideSurface.Canvas.DrawImage(ContentCache, Particles[0].X, Particles[0].Y, AContentPaint)
      else
        SlideSurface.Canvas.DrawImage(ContentCache, CurrentX, CurrentY, AContentPaint);
    end;

    // 3. Draw Control Dot
    DotAlpha := ControlDot.ActualAlpha;
    if DotAlpha > 0.01 then
    begin
      FAlphaByte := Round(((FActualDotColor shr 24) and $FF) * DotAlpha);
      C1 := (FAlphaByte shl 24) or (FActualDotColor and $00FFFFFF);

      // Calculate darker version of dot color for 3D radial gradient effect
      DR := ((FActualDotColor shr 16) and $FF) div 3;
      DG := ((FActualDotColor shr 8) and $FF) div 3;
      DB := (FActualDotColor and $FF) div 3;
      C2 := (FAlphaByte shl 24) or (DR shl 16) or (DG shl 8) or DB;

      AControlDotPaint.Shader := TSkShader.MakeGradientRadial(TPointF.Create(ControlDot.X - 3, ControlDot.Y - 3), 15, C1, C2, TSkTileMode.Clamp);
      SlideSurface.Canvas.DrawCircle(ControlDot.X, ControlDot.Y, 9, AControlDotPaint);

      // Draw small specular highlight on the dot
      AHighlightPaint.Color := (Round($CC * DotAlpha) shl 24) or $00FFFFFF;
      SlideSurface.Canvas.DrawCircle(ControlDot.X - 3, ControlDot.Y - 3, 2.5, AHighlightPaint);
    end;

    // Finalize cache for this slide
    Cache := SlideSurface.MakeImageSnapshot;
    IsDirty := False;
  end;
end;

/// <summary>
/// Draws the static background dot-matrix based on Intensity property.
/// </summary>
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

  // Generate dot grid
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

/// <summary>
/// The main background loop. Continuously calculates physics, updates caches,
/// and composes the final image (FMainImage) to be drawn by the UI thread.
/// </summary>
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
begin
  // Pre-create Image Filters for performance
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

          // Smoothly lerp Actual Colors to Target Colors
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

          // Setup Color Filter Matrix to tint the blurred blob shape
          R := ((FActualItemColor shr 16) and $FF) / 255.0;
          G := ((FActualItemColor shr 8) and $FF) / 255.0;
          B := (FActualItemColor and $FF) / 255.0;
          LMatrix := TSkColorMatrix.Create(0, 0, 0, 0, R, 0, 0, 0, 0, G, 0, 0, 0, 0, B, 0, 0, 0, 2.5, -0.2 // Alpha multiplier for extra opacity
          );
          LBlackPaint.ColorFilter := TSkColorFilter.MakeMatrix(LMatrix);

          // Setup Drop Shadows for the blob
          LShadowDown := TSkImageFilter.MakeDropShadow(0, 4, 8, 8, FActualShadowColor, nil);
          LShadowUp := TSkImageFilter.MakeDropShadow(0, -2, 6, 6, FActualShadowColor, nil);
          LCombinedShadow := TSkImageFilter.MakeCompose(LShadowUp, LShadowDown);
          LBlackPaint.ImageFilter := LCombinedShadow;

          // Process all visible slides
          if Length(FVisibleSlides) > 0 then
          begin
            for S := 0 to High(FVisibleSlides) do
            begin
              // 1. PHYSICS: Update positions
              ProcessSlidePhysics(FVisibleSlides[S], NowTime, LW, LH);
              ProcessSlideConstraints(FVisibleSlides[S], NowTime, LW, LH);

              // Check if slide is completely dead (fallen off screen)
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

              // Check if slide requires a redraw
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

                  // Force redraw if mouse is interacting with this slide's bounds
                  if FIsMouseOver and not IsDragging then
                  begin
                    if (FMousePos.X > CurrentX - 70) and (FMousePos.X < CurrentX + ActualSlideW + 70) and (FMousePos.Y > CurrentY - 70) and (FMousePos.Y < CurrentY + ActualSlideH + 70) then
                      IsDirty := True;
                  end;
                end;
              end;

              // 2. CACHING: Redraw slide bitmap if marked dirty
              if FVisibleSlides[S].IsDirty then
              begin
                FAnyDirty := True;
                LChanged := True;
                ProcessSlideCaching(FVisibleSlides[S], NowTime, LW, LH, LBlurPaint, LBlackPaint, LContentPaint, LControlDotPaint, LHighlightPaint);
              end;
            end;

            // Cleanup dead slides from array
            for i := High(FVisibleSlides) downto 0 do
              if FVisibleSlides[i].IsDead then
                System.Delete(FVisibleSlides, i, 1);
          end;

          if FMainImage = nil then
            FAnyDirty := True;

          // 3. COMPOSITE: Draw all slides onto the main surface
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

            // Draw normal slides first
            for S := 0 to High(FVisibleSlides) do
            begin
              if not FVisibleSlides[S].IsDragging then
                if FVisibleSlides[S].Cache <> nil then
                  FMainSurface.Canvas.DrawImage(FVisibleSlides[S].Cache, 0, 0);
            end;

            // Draw dragged slide last so it appears on top
            if (FDraggedSlideIdx >= 0) and (FDraggedSlideIdx <= High(FVisibleSlides)) and (FVisibleSlides[FDraggedSlideIdx].Cache <> nil) then
              FMainSurface.Canvas.DrawImage(FVisibleSlides[FDraggedSlideIdx].Cache, 0, 0);

            FMainImage := FMainSurface.MakeImageSnapshot;
            FAnyDirty := False;
            LChanged := True;
          end;
        end;
      finally
        FLock.Release;
      end;

      // Trigger UI Thread redraw if something changed
      if LChanged or FIsMouseOver or FIsDragging then
        SafeInvalidate;
    end;

    // Adaptive sleep to save CPU when idle, but smooth when interacting
    if LChanged or FIsMouseOver or FIsDragging then
      Sleep(16) // ~60 FPS
    else
      Sleep(50); // Idle state
  end;
end;

procedure TAliveGrid.StopThread;
begin
  FActive := False;
  if Assigned(FThread) then
  begin
    FThread.Terminate;
    Sleep(50); // Allow thread to exit gracefully
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

/// <summary>
/// Returns the bounding box for the control dot of a specific slide.
/// Used for hit testing during mouse clicks.
/// </summary>
function TAliveGrid.GetDotRect(Idx: Integer): TRectF;
begin
  if (Idx < 0) or (Idx > High(FVisibleSlides)) then
    Exit(TRectF.Empty);

  with FVisibleSlides[Idx] do
  begin
    Result := TRectF.Create(ControlDot.X - 9, ControlDot.Y - 9, ControlDot.X + 9, ControlDot.Y + 9);
  end;
end;

/// <summary>
/// Handles control resizing. Rebuilds grids, updates caches, and realigns particles.
/// </summary>
procedure TAliveGrid.Resize;
var
  i, j, RequiredCols, LItemIdx: Integer;
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

      // Rebuild background if dimensions changed
      if (FLastWidth <> Round(FCurrentWidth)) or (FLastHeight <> Round(FCurrentHeight)) then
      begin
        FLastWidth := Round(FCurrentWidth);
        FLastHeight := Round(FCurrentHeight);
        DrawBackgroundCache;
        FNeedsTextCacheUpdate := True;
      end;

      if FNeedsTextCacheUpdate then
        UpdateTextCache;

      // Realign all visible slides to new dimensions
      for i := 0 to High(FVisibleSlides) do
      begin
        FVisibleSlides[i].ActualSlideW := FCurrentWidth - (BorderGap * 2);
        FVisibleSlides[i].ActualSlideH := BaseSlideH;

        // Adjust particle columns based on new width
        RequiredCols := Max(10, Round(FVisibleSlides[i].ActualSlideW / MinSpaceX));
        if FVisibleSlides[i].Cols <> RequiredCols then
        begin
          FVisibleSlides[i].Cols := RequiredCols;
          SetLength(FVisibleSlides[i].Particles, FVisibleSlides[i].Cols * SlideRows);
          FVisibleSlides[i].TopRightIdx := (FVisibleSlides[i].Cols - 1) * SlideRows;
        end;

        // Recalculate resting distances
        SpaceX := FVisibleSlides[i].ActualSlideW / (FVisibleSlides[i].Cols - 1);
        SpaceY := FVisibleSlides[i].ActualSlideH / (SlideRows - 1);
        FVisibleSlides[i].RestX := SpaceX;
        FVisibleSlides[i].RestY := SpaceY;
        FVisibleSlides[i].RestDiag := Sqrt(SpaceX * SpaceX + SpaceY * SpaceY);

        // Regenerate Content Cache (Text/Image) for new width
        LItemIdx := FindItemIdxByID(FVisibleSlides[i].ItemID);
        if LItemIdx <> -1 then
          GenerateContentCache(FVisibleSlides[i], FAllItems[LItemIdx]);

        // Re-anchor particles
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

        // Hide dots during resize
        FVisibleSlides[i].ControlDot.TargetAlpha := 0;
        FVisibleSlides[i].ControlDot.ActualAlpha := 0;

        FVisibleSlides[i].IsDirty := True;
      end;

      // Force immediate redraw of main surface during resize
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

  // Re-show dots if mouse isn't held down
  if not FMouseIsDown then
  begin
    FIsResizing := False;
    for i := 0 to High(FVisibleSlides) do
    begin
      if not FVisibleSlides[i].IsRemoving then
        FVisibleSlides[i].ControlDot.TargetAlpha := 1.0;
    end;
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

    FLock.Acquire;
    try
      // Hit test: Iterate top-down (Z-Order)
      for i := 0 to High(FVisibleSlides) do
      begin
        if not FVisibleSlides[i].IsRemoving and (X >= FVisibleSlides[i].CurrentX) and (X <= FVisibleSlides[i].CurrentX + FVisibleSlides[i].ActualSlideW) and (Y >= FVisibleSlides[i].CurrentY) and (Y <= FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH) then
        begin
          FMouseDownSlideIdx := i;

          // Check if mouse is over the Control Dot
          LDotRect := GetDotRect(i);
          if LDotRect.Contains(TPointF.Create(X, Y)) then
            FMouseIsDownOnDot := True;

          FDraggedSlideIdx := i;
          FDragOffsetX := X - FVisibleSlides[i].CurrentX;
          FDragOffsetY := Y - FVisibleSlides[i].CurrentY;

          // Fire appropriate MouseDown event
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
  i: Integer;
begin
  inherited;
  FMousePos := TPointF.Create(X, Y);
  FIsMouseOver := True;

  // Handle Drag & Drop Reordering
  if FMouseIsDown and (FDraggedSlideIdx <> -1) then
  begin
    // Start dragging only if mouse moved beyond a threshold
    if not FIsDragging then
    begin
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

    // Update drag position and reorder array if crossing boundaries
    if FIsDragging and (FDraggedSlideIdx <= High(FVisibleSlides)) then
    begin
      FLock.Acquire;
      try
        FVisibleSlides[FDraggedSlideIdx].DragTargetX := X - FDragOffsetX;
        FVisibleSlides[FDraggedSlideIdx].DragTargetY := Y - FDragOffsetY;
        FVisibleSlides[FDraggedSlideIdx].IsDirty := True;
        FAnyDirty := True;

        // Check if dragged slide overlaps with others to swap positions
        for i := 0 to High(FVisibleSlides) do
        begin
          if (i = FDraggedSlideIdx) or FVisibleSlides[i].IsRemoving then
            Continue;

          // Dragged Down
          if (FDraggedSlideIdx < i) and (Y > FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH / 2) then
          begin
            SwapSlides(FDraggedSlideIdx, i);
            FDraggedSlideIdx := i;
            UpdateTargets;
          end
          // Dragged Up
          else if (FDraggedSlideIdx > i) and (Y < FVisibleSlides[i].CurrentY + FVisibleSlides[i].ActualSlideH / 2) then
          begin
            SwapSlides(i, FDraggedSlideIdx);
            FDraggedSlideIdx := i;
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

  // End Dragging
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

  // Fire Click events if not dragging
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

  // Reset drag state
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

  // Hit test for Double Clicks
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
  Redraw;
end;

/// <summary>
/// The final FMX paint pass. Simply draws the pre-rendered FMainImage.
/// All heavy lifting is done in the background thread.
/// </summary>
procedure TAliveGrid.Draw(const ACanvas: ISkCanvas; const ADest: TRectF; const AOpacity: Single);
begin
  if FMainImage <> nil then
    ACanvas.DrawImage(FMainImage, 0, 0, nil)
  else
    ACanvas.Clear(TAlphaColors.Black);
end;

end.

