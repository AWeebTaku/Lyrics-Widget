const VisualizerStyles = {
  Bars: 0,
  Wave: 1,
  Blocks: 2,
  // the lyric widget's own styles (viz/styles.js)
  PeakBars: 3,
  LedMeter: 4,
  Mountain: 5,
  Scope: 6,
  PixelMatrix: 7,
  FloatingDots: 8,
  TechLine: 9,
  RadialBurst: 10,
  PulseOrb: 11,
  Ribbon: 12,
  Sparkles: 13,
  GravitySparks: 14,
  Plasma: 15, // GPU shader (viz/PlasmaShader.qml)
  OrbitRing: 16,
  Terrain: 17, // GPU
  Tunnel: 18,  // GPU
  StereoScope: 19,
  Custom: 20,  // a QML file the user wrote (viz/CustomViz.qml)
  CrtScope: 21,
  SilkRibbon: 22,
};

// styles drawn by a fragment shader instead of the canvas
function isGpuStyle(s) {
  return s === VisualizerStyles.Plasma || s === VisualizerStyles.Terrain || s === VisualizerStyles.Tunnel;
}

// styles drawn as a line over the width (bars are spaced by the gap, the points of a line are spread across)
function isLineStyle(s) {
  return s === VisualizerStyles.Wave || s === VisualizerStyles.Mountain || s === VisualizerStyles.Scope
      || s === VisualizerStyles.TechLine || s === VisualizerStyles.Ribbon || s === VisualizerStyles.CrtScope
      || s === VisualizerStyles.SilkRibbon;
}
// styles that are the lyric widget's own (not the original three)
function isOwnStyle(s) { return s > VisualizerStyles.Blocks; }

const Orientation = {
  Top: 0,
  Bottom: 1,
  Left: 2,
  Right: 3,
};

const ColorSourceType = {
  Custom: 0,
  SystemTheme: 1,
  List: 2,
  Random: 3,
  // 4-6 unused
  Hue: 7,
};

const WaveMode = {
  Curve: 0,
  Square: 1,
  Triangle: 2
};
