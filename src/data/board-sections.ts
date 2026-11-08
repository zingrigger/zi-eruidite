import type { UIKey } from "@/lib/i18n"

/**
 * 玩具柜的一件展品。文案只存 `UI_STRINGS` 的 key，不存字符串——与 `blogTitle`
 * 同为界面文案，由 i18n.ts 统一管，缺语言时构建期即报错。
 */
export type BoardSection = {
  slug: string
  titleKey: UIKey
  descKey: UIKey
  /** 宽屏才摆得开：窄屏列表藏掉这一条，子页只留页头与提示。 */
  wideOnly?: boolean
}

/** 顺序即 /board 列表顺序，也是 /board/<slug> 的路由来源。 */
export const BOARD_SECTIONS: BoardSection[] = [
  {
    slug: "stamps",
    titleKey: "stampsTitle",
    descKey: "stampsDesc",
    wideOnly: true,
  },
  {
    slug: "lenticular-card",
    titleKey: "boardLensTitle",
    descKey: "lenticularDesc",
  },
  { slug: "tickets", titleKey: "ticketsTitle", descKey: "ticketsDesc" },
  { slug: "birds", titleKey: "birdsTitle", descKey: "birdsDesc" },
]
