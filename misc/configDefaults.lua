if not NotPlater then return end

function NotPlater:LoadDefaultConfig()
    self.defaults = {
        global = {
            recentlySeenCache = {
                data = {},
                stats = {
                    hits = 0,
                    misses = 0,
                    added = 0,
                    pruned = 0
                },
                version = 1
            }
        },
        profile = {
            guildCache = {
                general = {
                    enable = true,
                    useGuildClassColors = true,
                    playersOnly = false,
                    showCacheMessages = true,
                },
                advanced = {
                    updateThrottle = 2,
                    debugMode = false,
                },
            },
            partyRaidCache = {
                general = {
                    enable = true,
                    usePartyRaidColors = true,
                    showCacheMessages = true,
                },
                advanced = {
                    debugMode = false,
                },
            },
            recentlySeenCache = {
                general = {
                    enable = true,
                    useRecentlySeenColors = true,
                    showCacheMessages = false,
                    pruneDays = 7,
                    maxEntries = 500,
                },
                advanced = {
                    debugMode = false,
                },
            },
            threatIcon = {
                general = {
                    enable = true,
                    opacity = 1,
                    visibility = "combat",
                },
                size = {
                    width = 36,
                    height = 36,
                },
                position = {
                    anchor = "RIGHT",
                    xOffset = -32,
                    yOffset = 0,
                },
            },
            healthBar = {
                statusBar = {
                    general = {
                        enable = true,
                        texture = "NotPlater HealthBar",
                    },
                    background = {
                        enable = true,
                        color = {0.1, 0.1, 0.1, 0.8},
                        texture = "NotPlater Background",
                    },
                    size = {
                        width = 112,
                        height = 14,
                    },
                    border = {
                        enable = true,
                        color = {0, 0, 0, 0.8},
                        thickness = 1
                    },
                },
                coloring = {
                    system = "reaction", -- "reaction" or "class"
                    reactionColors = {
                        hostile = {r = 1, g = 0, b = 0, a = 1},
                        neutral = {r = 1, g = 1, b = 0, a = 1},
                        friendly = {r = 0, g = 1, b = 0, a = 1},
                    },
                    classColors = {
                        enable = true,
                        playersOnly = true, -- Only apply class colors to players, not NPCs
                    },
                },
                unitFilters = {
                    showPlayerTotems = true,    -- Show other players' totems
                    showOwnTotems = true,       -- Show your own totems
                    showOwnPet = true,          -- Show your own pet/minion
                    showOtherPlayerPets = true, -- Show other players' pets/minions
                },
                healthText = {
                    general = {
                        enable = true,
                        displayType = "both",
                        color = {1, 1, 1, 1},
                        name = "Arial Narrow",
                        size = 10,
                        border = "OUTLINE",
                    },
                    position = {
                        anchor = "CENTER",
                        xOffset = 0,
                        yOffset = 0,
                    },
                    shadow = {
                        enable = false,
                        color = {0, 0, 0, 1 },
                        xOffset = 0,
                        yOffset = 0
                    }
                },
                smoothing = {
                    general = {
                        enable = false,
                        mode = "smooth",
                        speed = 2.5,
                    },
                    cutaway = {
                        enable = true,
                        duration = 1.5,
                        darkenFactor = 0.6,
                        fadeOut = false,
                    },
                },
            },
            castBar = {
                statusBar = {
                    general = {
                        enable = true,
                        texture = "NotPlater Default",
                        color = {0.765, 0.525, 0, 1},
                    },
                    background = {
                        enable = true,
                        texture = "NotPlater Background",
                        color = {0.1, 0.1, 0.1, 0.8},
                    },
                    size = {
                        width = 112,
                        height = 14,
                    },
                    position = {
                        anchor = "BOTTOM",
                        xOffset = 0,
                        yOffset = -1,
                    },
                    border = {
                        enable = false,
                        color = {0, 0, 0, 1},
                        thickness = 1
                    },
                },
                spellIcon = {
                    general = {
                        opacity = 1
                    },
                    size = {
                        width = 14,
                        height = 14
                    },
                    position = {
                        anchor = "LEFT",
                        xOffset = 0,
                        yOffset = 0,
                    },
                    border = {
                        enable = false,
                        color = {0, 0, 0, 1},
                        thickness = 1
                    },
                    background = {
                        enable = false,
                        texture = "NotPlater Background",
                        color = {0.5, 0.5, 0.5, 0.8},
                    }
                },
                spellTimeText = {
                    general = {
                        enable = true,
                        displayType = "timeleft",
                        color = {1, 1, 1, 1},
                        size = 10,
                        border = "OUTLINE",
                        name = "Arial Narrow"
                    },
                    position = {
                        anchor = "RIGHT",
                        xOffset = 0,
                        yOffset = 0
                    },
                    shadow = {
                        enable = false,
                        color = {0, 0, 0, 1},
                        xOffset = 0,
                        yOffset = 0
                    }
                },
                spellNameText = {
                    general = {
                        enable = true,
                        color = {1, 1, 1, 1},
                        name = "Arial Narrow",
                        size = 10,
                        border = "OUTLINE",
                        maxLetters = 10,
                    },
                    position = {
                        anchor = "CENTER",
                        xOffset = 0,
                        yOffset = 0,
                    },
                    shadow = {
                        enable = false,
                        color = {0, 0, 0, 1},
                        xOffset = 0,
                        yOffset = 0
                    }
                },
            },
            nameText = {
                general = {
                    enable = true,
                    name = "Arial Narrow",
                    size = 11,
                    border = ""
                },
                position = {
                    anchor = "BOTTOM",
                    xOffset = 0,
                    yOffset = -12
                },
                shadow = {
                    enable = true,
                    color = {0, 0, 0, 1},
                    xOffset = 0,
                    yOffset = 0
                }
            },
            levelText = {
                general = {
                    enable = true,
                    name = "Arial Narrow",
                    opacity = 0.7,
                    size = 8,
                    border = ""
                },
                position = {
                    anchor = "TOPRIGHT",
                    xOffset = -2,
                    yOffset = 10 
                },
                shadow = {
                    enable = true,
                    color = {0, 0, 0, 1},
                    xOffset = 0,
                    yOffset = 0
                }
            },
            raidIcon = {
                general = {
                    opacity = 1,
                },
                size = {
                    width = 20,
                    height = 20,
                },
                position = {
                    anchor = "LEFT",
                    xOffset = -5,
                    yOffset = 0,
                }
            },
            bossIcon = {
                general = {
                    opacity = 1,
                },
                size = {
                    width = 20,
                    height = 20,
                },
                position = {
                    anchor = "RIGHT",
                    xOffset = 5,
                    yOffset = 0,
                }
            },
            target = {
                general = {
                    scale = {
                        scalingFactor = 1.11,
                        healthBar = true,
                        castBar = true,
                        nameText = true,
                        levelText = false,
                        raidIcon = false,
                        bossIcon = false,
                        targetTargetText = false,
                        threatIcon = false,
                    },
                    border = {
                        indicator = {
                            enable = true,
                            selection = "Silver"
                        },
                        highlight = {
                            enable = true,
                            texture = NotPlater.defaultHighlightTexture,
                            color = {0, 0.521568, 1, 0.75},
                            thickness = 14
                        },
                    },
                    overlay = {
                        enable = true,
                        texture = "Flat",
                        color = {1, 1, 1, 0.05}
                    },
                    nonTargetAlpha = {
                        enable = true,
                        opacity = 0.95
                    },
                    nonTargetShading = {
                        enable = true,
                        opacity = 0.4
                    },
                    mouseoverHighlight = {
                        enable = true,
                        opacity = 0.5
                    },
                },
                targetTargetText = {
                    general = {
                        enable = false,
                        color = {1, 1, 1, 1},
                        name = "Arial Narrow",
                        size = 8,
                        border = "",
                        maxLetters = 6
                    },
                    position = {
                        anchor = "CENTER",
                        xOffset = 44,
                        yOffset = -3,
                    },
                    shadow = {
                        enable = false,
                        color = {0, 0, 0, 1},
                        xOffset = 0,
                        yOffset = 0
                    }
                },
            },
            stacking = {
                general = {
                    enable = false,
                    overlappingCastbars = true,
                },
                margin = {
                    xStacking = 0,
                    yStacking = 0,
                },
                frameStrata = {
                    normalFrame = "LOW",
                    targetFrame = "MEDIUM"
                },
            },
            simulator = {
                general = {
                    showOnConfig = true
                },
                size = {
                    width = 200,
                    height = 100
                },
            },
        },
    }
end