package com.hxgny.app.data

enum class OneColumnSlug(
    val slug: String,
    val sheetUrl: String?,
    val columnName: String? = null,
    val assetName: String? = null
) {
    SchoolIntro(
        slug = "school_intro",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/schoolintro"
    ),
    JoinUs(
        slug = "join",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/joinus"
    ),
    LostFound(
        slug = "lostfound",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/lostnFound"
    ),
    Sponsors(
        slug = "sponsors",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/sponsors"
    ),
    Contact(
        slug = "contact",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/contact"
    ),
    WeeklyNews(
        slug = "weeklynews",
        sheetUrl = "https://opensheet.vercel.app/1qgbo7IlKkuFpCTYzrtIWHwjo0K6zItfyEeY6t_YbLV4/notice"
    );
}

object SheetConfig {
    const val CLASSES_SHEET_URL = "https://opensheet.vercel.app/1uuM1vd0U1YDiHCnB9M-40hZIltGE0ij3ELVOBcnjRog/test"
}
