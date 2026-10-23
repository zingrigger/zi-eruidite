/* 票券「倾斜」交互的客户端接线：鼠标移到某枚票券上，它朝指针 3D 倾斜，移开靠弹簧回正。
   物理复用光栅卡的 lenticular-spring（targetFromPointer / advanceAxes / DEFAULT_SPRING），
   于是手感与光栅卡同源、不重复造轮子。这里只做倾斜——没有面切换、没有 slider 语义。

   3D 变换落在 <ticket-slot>（父），而票券的 filter:drop-shadow 留在子 <ticket-card>（子）：
   3D 在父、filter 在子，绕开了「filter 压平 3D」的坑，阴影随票券一起倾斜。本文件只往
   slot 写 --tk-rx / --tk-ry（带 deg），长相在 TicketSection 的 scoped CSS 里读这两个变量。
   名字带 --tk- 前缀不是风格问题：--rx/--ry 已被 lenticular.css 用 @property 注册成全局
   <number>（@property 无作用域），往它写带 deg 的值会整条作废。 */

import {
  DEFAULT_SPRING,
  advanceAxes,
  targetFromPointer,
  type SpringState,
  type Vec2,
} from "@/lib/lenticular-spring"

export type TiltHandle = { destroy(): void }

/** 票券比光栅卡小，满倾收一点更耐看 */
const MAX_TILT = 12

/** 归一化坐标钳进 [0,1]：指针贴着边缘也不该越过满倾 */
const unit = (v: number): number => (v < 0 ? 0 : v > 1 ? 1 : v)

/**
 * 给 showcase 下每个 ticket-slot 挂上悬停倾斜。返回 handle.destroy() 摘掉全部监听
 * 并把 --tk-rx/--tk-ry 归零。倾斜没有开关、纯装饰，于是 `prefers-reduced-motion: reduce`
 * 下直接夺走它：不弹簧也不即时跟随，任何入口都当场把角度抹回平放态。
 */
export function mountTicketTilt(showcase: HTMLElement): TiltHandle {
  const cleanups: (() => void)[] = []
  for (const slot of showcase.querySelectorAll<HTMLElement>("ticket-slot")) {
    cleanups.push(mountSlot(slot))
  }
  return {
    destroy: () => {
      for (const fn of cleanups) fn()
    },
  }
}

function mountSlot(slot: HTMLElement): () => void {
  // 用票券本体（2D 旋转、未 3D 倾斜）的矩形算指针位置；进入时冻结一份，
  // 免得倾斜改变 getBoundingClientRect 反过来影响映射（自反馈抖动）
  const card = slot.querySelector<HTMLElement>("ticket-card") ?? slot
  const reduce = matchMedia("(prefers-reduced-motion: reduce)")
  let rect: DOMRect | null = null
  let target: Vec2 = { rx: 0, ry: 0 }
  let state: SpringState = {
    cur: { rx: 0, ry: 0 },
    vel: { rx: 0, ry: 0 },
    acc: 0,
  }
  let raf = 0
  let prev = 0
  const written = new Map<string, string>()

  const setVar = (name: string, value: string): void => {
    if (written.get(name) === value) return
    written.set(name, value)
    slot.style.setProperty(name, value)
  }
  const write = (): void => {
    setVar("--tk-rx", `${state.cur.rx.toFixed(3)}deg`)
    setVar("--tk-ry", `${state.cur.ry.toFixed(3)}deg`)
  }
  const atRest = (): boolean => {
    if (target.rx !== 0 || target.ry !== 0) return false
    const e = 0.01
    return (
      Math.abs(state.cur.rx) < e &&
      Math.abs(state.cur.ry) < e &&
      Math.abs(state.vel.rx) < e &&
      Math.abs(state.vel.ry) < e
    )
  }
  const stop = (): void => {
    if (raf) {
      cancelAnimationFrame(raf)
      raf = 0
    }
    slot.style.removeProperty("will-change")
  }
  /** 抹平：目标角与当前角一起归零并写出，再停循环（reduce 下的唯一出路） */
  const settle = (): void => {
    target = { rx: 0, ry: 0 }
    state = { cur: { rx: 0, ry: 0 }, vel: { rx: 0, ry: 0 }, acc: 0 }
    write()
    stop()
  }
  const tick = (time: number): void => {
    // 循环跑着时偏好被改成 reduce：当场抹平，弹簧不再继续抽倾斜
    if (reduce.matches) {
      settle()
      return
    }
    const dt = prev ? Math.min((time - prev) / 1000, 0.25) : 0
    prev = time
    state = advanceAxes(state, target, DEFAULT_SPRING, dt)
    if (atRest()) {
      state = { cur: { rx: 0, ry: 0 }, vel: { rx: 0, ry: 0 }, acc: 0 }
      write()
      stop()
      return
    }
    write()
    raf = requestAnimationFrame(tick)
  }
  const start = (): void => {
    if (raf) return
    prev = 0
    slot.style.setProperty("will-change", "transform")
    raf = requestAnimationFrame(tick)
  }

  /* reduce 下三个入口全部不进：不读矩形、不起循环，票券根本不倾 */
  const onEnter = (): void => {
    if (reduce.matches) return
    rect = card.getBoundingClientRect()
    start()
  }
  const onMove = (e: PointerEvent): void => {
    if (reduce.matches) return
    if (!rect) rect = card.getBoundingClientRect()
    const nx = unit((e.clientX - rect.left) / rect.width)
    const ny = unit((e.clientY - rect.top) / rect.height)
    target = targetFromPointer(nx, ny, MAX_TILT)
    start()
  }
  const onLeave = (): void => {
    target = { rx: 0, ry: 0 }
    rect = null
    if (reduce.matches) return
    start()
  }

  slot.addEventListener("pointerenter", onEnter)
  slot.addEventListener("pointermove", onMove)
  slot.addEventListener("pointerleave", onLeave)

  return () => {
    stop()
    slot.removeEventListener("pointerenter", onEnter)
    slot.removeEventListener("pointermove", onMove)
    slot.removeEventListener("pointerleave", onLeave)
    slot.style.removeProperty("--tk-rx")
    slot.style.removeProperty("--tk-ry")
    slot.style.removeProperty("will-change")
  }
}
