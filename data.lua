-- Data like id's and dopdown keys

DD_TYPES = 
{
    --[[ALL_TYPES =
    {
    	skips = {res = true, skipFrameCheck = true},
        sortID = 1
    },]]
    PRIMARY_WEAPON =
    {
		typeName = "weapon",
		slotIdx = 1,
		skips = {res = true, skipFrameCheck = false},
        sortID = 2,
	},
    SECONDARY_WEAPON =
    {
		typeName = "weapon",
		slotIdx = 2,
		skips = {res = true, skipFrameCheck = true},
        sortID = 3
    },
    ABILITY =
    {
        typeName = "ablity",
        skips = {res = true, skipFrameCheck = false},
        sortID = 4
    },
    WEAPON_MODULE =
    {
        typeName = "module",
        module_location = "weapon",
        skips = {res = true, skipFrameCheck = true},
        sortID = 5
    },
    ABILITY_MODULE =
    {
        typeName = "module",
        module_location = "ability_module",
        skips = {res = true, skipFrameCheck = true},
        sortID = 6
    },
    BATTLEFRAME_CORE =
    {
		typeName = "frame_module",
		all = true,
		skips = {res = true, skipFrameCheck = true},
        sortID = 7
    },
    JUNK_SALVAGE =
    {
		typeName = "salvage",
		subTypeIds = {"3617"},
		skips = {res = true, skipFrameCheck = true, skipRarityCheck = true, skipLevelCheck = true},
        sortID = 8
    }
};

-- I could get this from the api  >,>
DD_FRAMES = 
{
	ANY_FRAME = 
	{
		certId = "",
        sortID = 1
	},
	ACCORD_BIOTECH = 
	{
        certId = 738,
        sortID = 2
	},
	DRAGONFLY = 
	{
        certId = 739,
		baseFrame = "ACCORD_BIOTECH",
        sortID = 3
	},
	RECLUSE = 
	{
        certId = 740,
		baseFrame = "ACCORD_BIOTECH",
        sortID = 4
	},
	ACCORD_ASSAULT = 
	{
        certId = 732,
        sortID = 5
	},
	FIRECAT = 
	{
        certId = 733,
		baseFrame = "ACCORD_ASSAULT",
        sortID = 6
	},
	TIGERCLAW = 
	{
        certId = 734,
		baseFrame = "ACCORD_ASSAULT",
        sortID = 7
	},
	ACCORD_DREADNAUGHT = 
	{
        certId = 741,
        sortID = 8
	},
	ARSENAL = 
	{
        certId = 748,
		baseFrame = "ACCORD_DREADNAUGHT",
        sortID = 9
	},
	MAMMOTH = 
	{
        certId = 742,
		baseFrame = "ACCORD_DREADNAUGHT",
        sortID = 10
	},
	RHINO = 
	{
        certId = 743,
		baseFrame = "ACCORD_DREADNAUGHT",
        sortID = 11
	},
	ACCORD_ENGINEER = 
	{
        certId = 735,
        sortID = 12
	},
	BASTION = 
	{
        certId = 737,
		baseFrame = "ACCORD_ENGINEER",
        sortID = 13
	},
	ELECTRON = 
	{
        certId = 736,
		baseFrame = "ACCORD_ENGINEER",
        sortID = 14
	},
	ACCORD_RECON = 
	{
        certId = 744,
        sortID = 15
	},
	NIGHTHAWK = 
	{
        certId = 745,
		baseFrame = "ACCORD_RECON",
        sortID = 16
	},
	RAPTOR = 
	{
        certId = 746,
		baseFrame = "ACCORD_RECON",
        sortID = 17
	},
};

DD_COLORS = 
{
	ORANGE =
    {
        sortID = 1,
		raritys = {"legendary "}
    },
	ORANGE_AND_BELOW =
    {
        sortID = 2,
		raritys = {"legendary", "prototype", "epic", "rare", "uncommon", "common"}
    },
	YELLOW =
    {
        sortID = 3,
		raritys = {"prototype"}
    },
	YELLOW_AND_BELOW =
    {
        sortID = 4,
		raritys = {"prototype", "epic", "rare", "uncommon", "common"}
    },
	PURPLE =
    {
        sortID = 5,
		raritys = {"epic"}
    },
	PURPLE_AND_BELOW =
    {
        sortID = 6,
		raritys = {"epic", "rare", "uncommon", "common"}
    },
	BLUE =
    {
        sortID = 7,
		raritys = {"rare"}
    },
	BLUE_AND_BELOW =
    {
        sortID = 8,
		raritys = {"rare", "uncommon", "common"}
    },
	GREEN =
    {
        sortID = 9,
		raritys = {"uncommon"}
    },
	GREEN_AND_BELOW =
    {
        sortID = 10,
		raritys = {"uncommon", "common"}
    },
	WHITE =
    {
        sortID = 11,
		raritys = {"common"}
    },
};

DD_WHEN = 
{
	"ON_PICKUP",
	"INV_PCT_FULL"
};

DD_ACTIONS = 
{
	"SALVAGE",
	"PROMPT",
	"Q_FOR_REVIEW"
};

-- Default filter settings
DEFAULT_FILTER_DATA =
{
	typeName = "PRIMARY_WEAPON",
	frame = "ANY_FRAME",
	levelFrom = 1,
	levelTo = 20,
	color = #DD_COLORS,
	when = "ON_PICKUP",
	action = "Q_FOR_REVIEW",
	precentFull = 80
};

ZONES = 
{
	--[[
		zone_id = 12, 
		title = "Nothing"
	}, ]]
	{
		zone_id = 162, 
		title = "Devil's Tusk"
	}, 
	{
		zone_id = 448, 
		title = "New Eden"
	}, 
	{
		zone_id = 805, 
		title = "Epicenter"
	}, 
	{
		zone_id = 833, 
		title = "Campaign Chapter 1 - Blackwater Anomaly"
	}, 
	{
		zone_id = 861, 
		title = "Campaign Chapter 1 - Research Station"
	}, 
	{
		zone_id = 863, 
		title = "Cliff's Edge"
	}, 
	{
		zone_id = 864, 
		title = "Campaign Chapter 1 - Bandit Cave"
	}, 
	{
		zone_id = 865, 
		title = "Abyss"
	}, 
	{
		zone_id = 868, 
		title = "Cinerarium"
	}, 
	{
		zone_id = 878, 
		title = "The Wages of SIN"
	}, 
	{
		zone_id = 1003, 
		title = "Campaign Chapter 1 - Harvester Island"
	}, 
	{
		zone_id = 1007, 
		title = "Campaign Chapter 1 - Power Grab"
	}, 
	{
		zone_id = 1008, 
		title = "Campaign Chapter 1 - Risky Business"
	}, 
	{
		zone_id = 1021, 
		title = "Broken Peninsula"
	}, 
	{
		zone_id = 1022, 
		title = "Lair of the Destroyer"
	}, 
	{
		zone_id = 1024, 
		title = "The Wages of SIN"
	}, 
	{
		zone_id = 1028, 
		title = "Operation: Cinderblock"
	}, 
	{
		zone_id = 1030, 
		title = "Sertao"
	}, 
	{
		zone_id = 1051, 
		title = "Baneclaw Lair"
	}, 
	{
		zone_id = 1054, 
		title = "Devils Tusk "
	}
};

HEADER_LOOKUP = 
{
	FLT_TYPE = "typeName",
	FLT_FRAME = "frame",
	FLT_LEVEL_RANGE = "levelFrom",
	FLT_COLOR = "color",
	FLT_WHEN = "when",
	FLT_ACTION = "action"
};