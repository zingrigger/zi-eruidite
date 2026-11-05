export type VoronoiItem = { key: string; weight: number }

export type VoronoiPoint = { x: number; y: number }

export type VoronoiCell = {
  key: string
  points: VoronoiPoint[]
  box: { x: number; y: number; w: number; h: number }
  label: { x: number; y: number }
  inradius: number
  share: number
}

type Site = { key: string; x: number; y: number; w: number }
type Box = { x: number; y: number; w: number; h: number }

const DEFAULT_SEED = 20261105
const DEFAULT_GAP = 6
const DEFAULT_MAX_ITERATIONS = 400
const DEFAULT_TOLERANCE = 0.008

const round = (n: number, digits = 3) => {
  const scale = 10 ** digits
  return Math.round(n * scale) / scale
}

function mulberry32(seed: number): () => number {
  let state = seed >>> 0
  return () => {
    state = (state + 0x6d2b79f5) >>> 0
    let t = Math.imul(state ^ (state >>> 15), 1 | state)
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296
  }
}

function clipHalfPlane(
  poly: VoronoiPoint[],
  nx: number,
  ny: number,
  c: number,
): VoronoiPoint[] {
  const out: VoronoiPoint[] = []
  for (let i = 0; i < poly.length; i++) {
    const p = poly[i]
    const q = poly[(i + 1) % poly.length]
    const dp = nx * p.x + ny * p.y - c
    const dq = nx * q.x + ny * q.y - c
    if (dp <= 1e-9) out.push(p)
    if ((dp < -1e-9 && dq > 1e-9) || (dp > 1e-9 && dq < -1e-9)) {
      const t = dp / (dp - dq)
      out.push({ x: p.x + t * (q.x - p.x), y: p.y + t * (q.y - p.y) })
    }
  }
  return out
}

function cellOf(
  index: number,
  sites: Site[],
  container: VoronoiPoint[],
): VoronoiPoint[] {
  let poly = container
  const p = sites[index]
  for (let j = 0; j < sites.length; j++) {
    if (j === index) continue
    const q = sites[j]
    const nx = 2 * (q.x - p.x)
    const ny = 2 * (q.y - p.y)
    const c = q.x * q.x + q.y * q.y - p.x * p.x - p.y * p.y + p.w - q.w
    poly = clipHalfPlane(poly, nx, ny, c)
    if (poly.length < 3) return []
  }
  return poly
}

function areaOf(poly: VoronoiPoint[]): number {
  let sum = 0
  for (let i = 0; i < poly.length; i++) {
    const p = poly[i]
    const q = poly[(i + 1) % poly.length]
    sum += p.x * q.y - q.x * p.y
  }
  return sum / 2
}

function centroidOf(poly: VoronoiPoint[]): VoronoiPoint {
  let cx = 0
  let cy = 0
  let area = 0
  for (let i = 0; i < poly.length; i++) {
    const p = poly[i]
    const q = poly[(i + 1) % poly.length]
    const cross = p.x * q.y - q.x * p.y
    area += cross
    cx += (p.x + q.x) * cross
    cy += (p.y + q.y) * cross
  }
  area /= 2
  if (Math.abs(area) < 1e-9) {
    const n = poly.length
    return poly.reduce(
      (acc, p) => ({ x: acc.x + p.x / n, y: acc.y + p.y / n }),
      { x: 0, y: 0 },
    )
  }
  return { x: cx / (6 * area), y: cy / (6 * area) }
}

export function insetConvex(
  poly: VoronoiPoint[],
  distance: number,
): VoronoiPoint[] {
  if (distance <= 0) return poly
  const ccw = areaOf(poly) > 0
  let out = poly
  for (let i = 0; i < poly.length; i++) {
    const p = poly[i]
    const q = poly[(i + 1) % poly.length]
    const dx = q.x - p.x
    const dy = q.y - p.y
    const len = Math.hypot(dx, dy) || 1
    const nx = (ccw ? -dy : dy) / len
    const ny = (ccw ? dx : -dx) / len
    const c = nx * p.x + ny * p.y + distance
    out = clipHalfPlane(out, -nx, -ny, -c)
    if (out.length < 3) return []
  }
  return out
}

function bboxOf(poly: VoronoiPoint[]): Box {
  let minX = Infinity
  let minY = Infinity
  let maxX = -Infinity
  let maxY = -Infinity
  for (const p of poly) {
    minX = Math.min(minX, p.x)
    minY = Math.min(minY, p.y)
    maxX = Math.max(maxX, p.x)
    maxY = Math.max(maxY, p.y)
  }
  return { x: minX, y: minY, w: maxX - minX, h: maxY - minY }
}

function inradiusOf(poly: VoronoiPoint[], point: VoronoiPoint): number {
  let min = Infinity
  for (let i = 0; i < poly.length; i++) {
    const p = poly[i]
    const q = poly[(i + 1) % poly.length]
    const dx = q.x - p.x
    const dy = q.y - p.y
    const len = Math.hypot(dx, dy) || 1
    const dist =
      Math.abs(dy * point.x - dx * point.y + q.x * p.y - q.y * p.x) / len
    min = Math.min(min, dist)
  }
  return min
}

function gridSeeds(count: number, size: { width: number; height: number }) {
  const ratio = size.width / size.height
  const cols = Math.max(1, Math.ceil(Math.sqrt(count * ratio)))
  const rows = Math.max(1, Math.ceil(count / cols))
  return { cols, rows }
}

export function layoutVoronoiTreemap(
  items: VoronoiItem[],
  size: { width: number; height: number },
  options: {
    gap?: number
    seed?: number
    maxIterations?: number
    tolerance?: number
  } = {},
): VoronoiCell[] {
  const positive = items.filter((item) => item.weight > 0)
  if (positive.length === 0) return []

  const width = size.width
  const height = size.height
  const boardArea = width * height
  const totalWeight = positive.reduce((sum, item) => sum + item.weight, 0)
  const targets = positive.map(
    (item) => (item.weight / totalWeight) * boardArea,
  )
  const rand = mulberry32(options.seed ?? DEFAULT_SEED)
  const { cols, rows } = gridSeeds(positive.length, size)
  const cellW = width / cols
  const cellH = height / rows
  const jitterX = cellW * 0.45
  const jitterY = cellH * 0.35

  const sites: Site[] = positive.map((item, index) => {
    const col = index % cols
    const row = Math.floor(index / cols)
    return {
      key: item.key,
      x: Math.max(
        40,
        Math.min(width - 40, (col + 0.5) * cellW + (rand() - 0.5) * jitterX),
      ),
      y: Math.max(
        30,
        Math.min(height - 30, (row + 0.5) * cellH + (rand() - 0.5) * jitterY),
      ),
      w: targets[index] * 0.35,
    }
  })

  const container: VoronoiPoint[] = [
    { x: 0, y: 0 },
    { x: width, y: 0 },
    { x: width, y: height },
    { x: 0, y: height },
  ]

  const maxIterations = options.maxIterations ?? DEFAULT_MAX_ITERATIONS
  const tolerance = options.tolerance ?? DEFAULT_TOLERANCE

  for (let iter = 0; iter < maxIterations; iter++) {
    const cells = sites.map((_, i) => cellOf(i, sites, container))
    const areas = cells.map((poly) => (poly.length >= 3 ? areaOf(poly) : 0))
    const maxError = Math.max(
      ...areas.map((area, i) => Math.abs((area - targets[i]) / targets[i])),
    )
    if (maxError < tolerance) break

    const updates: number[] = []
    for (let i = 0; i < sites.length; i++) {
      const site = sites[i]
      const area = areas[i]
      let weight = site.w + 0.45 * (targets[i] - area)
      if (area < 1) weight += targets[i] * 0.8
      updates.push(weight)

      if (area > 1) {
        const center = centroidOf(cells[i])
        site.x += 0.18 * (center.x - site.x)
        site.y += 0.18 * (center.y - site.y)
      }
      site.x = Math.max(40, Math.min(width - 40, site.x))
      site.y = Math.max(30, Math.min(height - 30, site.y))
    }
    const mean = updates.reduce((a, b) => a + b, 0) / updates.length
    sites.forEach((site, i) => {
      site.w = updates[i] - mean
    })
  }

  const finalCells = sites.map((_, i) => cellOf(i, sites, container))
  const finalAreas = finalCells.map((poly) =>
    poly.length >= 3 ? areaOf(poly) : 0,
  )
  const gap = options.gap ?? DEFAULT_GAP

  const result: VoronoiCell[] = []
  for (let i = 0; i < positive.length; i++) {
    const raw = finalCells[i]
    if (raw.length < 3 || finalAreas[i] <= 0) continue
    const inset = insetConvex(raw, gap / 2)
    if (inset.length < 3 || areaOf(inset) <= 0) continue
    const box = bboxOf(inset)
    const center = centroidOf(inset)
    const label = {
      x: ((center.x - box.x) / box.w) * 100,
      y: ((center.y - box.y) / box.h) * 100,
    }
    result.push({
      key: positive[i].key,
      points: inset.map((p) => ({ x: round(p.x), y: round(p.y) })),
      box: {
        x: round(box.x),
        y: round(box.y),
        w: round(box.w),
        h: round(box.h),
      },
      label: { x: round(label.x, 2), y: round(label.y, 2) },
      inradius: round(inradiusOf(inset, center), 2),
      share: round(finalAreas[i] / boardArea, 4),
    })
  }

  return result
}
