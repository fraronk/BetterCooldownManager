local _, BCDM = ...

BCDM.Defaults = {
    global = {
        General = {
            Font = "Friz Quadrata TT",
            FontFlag = "OUTLINE",
            IconZoom = 0.1,
            CooldownText = {
                FontSize = 15,
                Colour = {1, 1, 1},
                Anchors = {"CENTER", "CENTER", 0, 0}
            },
        },
        Essential = {
            IconSize = 42,
            Anchors = {"CENTER", UIParent, "CENTER", 0, -275.1},
            Count = {
                FontSize = 15,
                Colour = {1, 1, 1},
                Anchors = {"BOTTOMRIGHT", "BOTTOMRIGHT", 0, 3}
            },
        },
        Utility = {
            IconSize = 36,
            Anchors = {"TOP", "EssentialCooldownViewer", "BOTTOM", 0, -2},
            Count = {
                FontSize = 12,
                Colour = {1, 1, 1},
                Anchors = {"BOTTOMRIGHT", "BOTTOMRIGHT", 0, 3}
            },
        },
        Buffs = {
            IconSize = 36,
            Anchors = {"BOTTOM", "EssentialCooldownViewer", "TOP", 0, 2},
            Count = {
                FontSize = 12,
                Colour = {1, 1, 1},
                Anchors = {"BOTTOMRIGHT", "BOTTOMRIGHT", 0, 3}
            },
        },
    }
}