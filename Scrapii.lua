--========================================
-- Scrapii
-- Arkii      7/07/14
--========================================
require "math";
require "table";
require "unicode";
require "lib/lib_MovablePanel";
require "lib/lib_Button";
require "lib/lib_RowScroller";
require "lib/lib_ContextMenu";
require "lib/lib_RoundedPopupWindow";
require "lib/lib_DropDownList";
require "lib/lib_Slider";
require "lib/lib_table";
require "lib/lib_Tooltip";
require "lib/lib_Items";
require "lib/lib_Debug";
require "lib/lib_ChatLib";
require "lib/lib_CheckBox";
require "lib/lib_PanelManager";
require "lib/lib_Callback2";
require "lib/lib_MultiArt";
require "lib/lib_Math";
require "lib/lib_HudNote";
require "lib/lib_InterfaceOptions";
require "lib/lib_Slash";
require "lib/lib_RoundedPopupWindow";
require "lib/lib_SubTypeIds";
require "./libs/lib_SimpleDialog";
require "./libs/lib_lokii";
require "./data";
require "./Ui";
-- Just include them all why don't I

--=====================
--		Constants    --
--=====================
HUD_NOTE_TIMEOUT = 100;
salvageQueueFlushDelay = 7;
NEW_FILTER_SET_ID = "__NEW__";

--=====================
--	   Variables     --
--=====================
zoneId = 0;
FiltersData = {};
FilteredItems = {};
c_cid = 0;
inventoryLimts =
{
	current = 0,
	max = 0,
	precent = 0
};

uiOpts =
{
	enableDebug = false,
	printSummary = true,
	printSummaryChan = "loot",
	reportRewards = false,
	processLoot = true,
	processRewards = true,
	inventorySalvaging = false,
	activeZones = {}, -- A table of zone ids to salvage items in, format "id = bool", so it can be index checked
	salvageInNullZones = false
};

-- Filter related configs
config =
{
	includeArchtype = true
};

salvageQueue = {};
salvageRewards = {};
reviewQueue = {};
finalisedQueue = {};
salvageCallBack = Callback2.Create();
isSalvageing = false;
activeFilterSet = "";
filterSets = nil;
playerID = nil;

-- List of sdb ids that we are to salvage once the OnInventoryEntryChange event for them fires
--[[ format 
"sdbid" = 
{
	quantity,
	filterData
}
]]
checkList = {};

--=====================
--      Events       --
--=====================
function OnComponentLoad(args)
	-- Lokii setup
    Lokii.AddLang("en", "./lang/EN");
	Lokii.AddLang("de", "./lang/DE");
	Lokii.AddLang("fr", "./lang/FR");
	Lokii.SetBaseLang("en");
	Lokii.SetToLocale();

	LoadConfig();
	GetZoneList();
	LoadSalvageRewards();
    Ui.Init();
	
	-- Migrate data
	local oldData = Component.GetSetting("FiltersData");
	if oldData then
		AddNewFilterSet("Default");
		SetActiveFilterSet("Default");
		FiltersData = oldData;
		SaveActiveFilterSet();
		Component.SaveSetting("FiltersData", nil);
	end

	activeFilterSet = Component.GetSetting("activefilterset") or "";
	if (activeFilterSet == "") then
		AddNewFilterSet("Default");
		SetActiveFilterSet("Default");
	end
	
	Ui.UpdateProfitsTootip(salvageRewards);
	FiltersData = Component.GetSetting("FiltersData") or {};
	filterSets = Component.GetSetting("filterSets") or {};
	Ui.UpdateFilterSets(filterSets, activeFilterSet);
	Ui.SetActiveFilterSet(activeFilterSet);
	
	CreateList();
	salvageCallBack:Bind(ProcessSalvageQueue);
	
	LIB_SLASH.BindCallback({slash_list="scrapii,scrap", description="", func=OnSlashOpen});
	LIB_SLASH.BindCallback({slash_list="srl,review", description="", func=OnSlashOpenReview});
	LIB_SLASH.BindCallback({slash_list="stest", description="", func=OnItemTest});
	LIB_SLASH.BindCallback({slash_list="stest2", description="", func=OnItemTest2});
end

function OnPlayerReady(args)
	c_cid = Player.GetTargetId();
	OnEnterZone();
	playerID = Player.GetCharacterId();
	
	-- See Mavoc I do listen, sometimes
	Debug.EnableLogging(IsUserAuthor() or uiOpts.enableDebug);
    UpdateInvWeight();
    Ui.UpdateActiveCharButton();

	-- Migrate to current cid
	local oldReviewQu = Component.GetSetting("reviewQueue");
	if oldReviewQu ~= nil then
		Print("Found old 'reviewQueue' data and migrating it to current character")
		Component.SaveSetting("reviewQueue_"..playerID, oldReviewQu);
		Component.SaveSetting("reviewQueue", nil);
	end

    LoadReviewQueue();
end

function OnInventoryEntryChange(args)
	Debug.Log("- OnInventoryEntryChange");

	for id, val in pairs(checkList) do
		if (id == tostring(args.sdb_id)) then
			Debug.Log("================== OnInventoryEntryChange ================");
			Debug.Log("SDB ID: ".. tostring(args.sdb_id).." GUID: ".. tostring(args.guid));
			local itemInfo = Game.GetItemInfoByType(args.sdb_id);
			itemInfo.item_sdb_id = args.sdb_id;
			itemInfo.lootArgs = {quantity = val.quantity};
			PreformFilterAction(val.filterData, itemInfo, args.guid);
			checkList[id] = nil;
		end
	end
end

function OnLootCollected(args)
	if (args.lootedToId ~= c_cid or not uiOpts.processLoot) then
		return;
	end

    local itemTypeId = args.itemTypeId;
    local info = Game.GetItemInfoByType(itemTypeId);

    if (info.flags and info.flags.is_salvageable) then
	    info.item_sdb_id = itemTypeId;
	    info.lootArgs = args;

		local result = CheckAgainstFilters(info);
	    if (result) then
	    	AddToCheckList(itemTypeId, result, args.quantity);
	    end
	end
end

function OnsalvageResponce(args)
	if (isSalvageing) then
		local summaryStr = "";
		local stats = {};

		for id, data in pairs(args) do
			if (id ~= "event") then
				local idx = tostring(data.item_sdb_id);
				salvageRewards[idx] = (salvageRewards[idx] or 0) + data.quantity;

				if (uiOpts.printSummary) then
					summaryStr = summaryStr.. unicode.format("%s x %s, ", data.quantity, ChatLib.EncodeItemLink(data.item_sdb_id));
				end

				if (uiOpts.reportRewards) then
					local info = Game.GetItemInfoByType(data.item_sdb_id);
					table.insert(stats, {id=data.item_sdb_id, name=info.name, desc=info.description, icon=info.web_icon, quantity=data.quantity});
				end
			end
		end

		PrintLoot(unicode.sub(summaryStr, 1, -3));

		SaveSalvageRewards();
		Ui.UpdateProfitsTootip(salvageRewards);

		if (uiOpts.reportRewards) then
			SendWebStats(stats);
		end

		isSalvageing = false;
	end
end

function OnInventoryWeightChanged(args)
	UpdateInvWeight();
end

function OnEncounterReward(args)
	Debug.Log(tostring(args));

	if (uiOpts.processRewards) then
		for id, data in pairs(args.rewards) do
			local itemTypeId = data.itemTypeId;
		    local info = Game.GetItemInfoByType(itemTypeId);

		    if (info.flags and info.flags.is_salvageable) then
			    info.item_sdb_id = itemTypeId;
			    info.lootArgs = data;

				local result = CheckAgainstFilters(info);
			    if (result) then
			    	AddToCheckList(itemTypeId, result, data.quantity);
			    end
			end
		end
	end
end

function OnFeedTestItem(itemID)
	Debug.Log("==== Test Item: "..itemID.. " ====");

	local info = Game.GetItemInfoByType(itemID);
	local result = CheckAgainstFilters(info);
    if (result) then
    	Debug.Log("Item matched filters");
    	result.is_test = true;
    	AddToCheckList(itemID, result, 1);

    	-- Fake an inventory change event
		OnInventoryEntryChange(
		{
			sdb_id = itemID,
			guid = nil
		});
    end
end

function OnEnterZone(args)
	zoneId = tostring(Game.GetZoneId());
end

--=====================
-- 	   Callbacks     --
--=====================
function OnSlashOpen()
	Ui.Show(true);
end

function OnSlashOpenReview()
	LoadReviewList();
end

function OnItemTest(args)
	OnFeedTestItem(args[1]);
end

function OnItemTest2(args)
	Print("--------- Testing Filters ---------");
	OnFeedTestItem("113993"); -- Myrmidon
	OnFeedTestItem("114506"); -- Sharpeye R36 Rifle
	OnFeedTestItem("114041"); -- Rolling Thunder
	OnFeedTestItem("114495"); -- Burrowing Sticky Launcher
	OnFeedTestItem("114319"); -- Governor
	OnFeedTestItem("107795"); -- Kanaloa Rifle
	OnFeedTestItem("107419"); -- Absorption Bomb
	OnFeedTestItem("86106"); -- Decoy
	OnFeedTestItem("94086"); -- Air Sprint Efficiency Battleframe Core
	OnFeedTestItem("99625"); -- Draconis Core
	OnFeedTestItem("93962"); -- Run Speed Battleframe Core
	OnFeedTestItem("92283"); -- Charging Module
	OnFeedTestItem("95801"); -- Havoc Module
	OnFeedTestItem("100359"); -- Energized Module
	OnFeedTestItem("96109"); -- Distant Module
	Print("-----------------------------------");
end

function OnClose(args)
    Ui.Show(false);
end

function OnCloseRP(args)
	Ui.ShowReview(false);
end

-- Called from the UI
function CreateNewFilter(data)
	if not FiltersData then
		FiltersData = {};
	end
	
    table.insert(FiltersData, data);
	SaveActiveFilterSet();
	Ui.AddFilterRow(#FiltersData, data);
end

function EditFilter(id, data)
	FiltersData[id] = data;
	SaveActiveFilterSet();
	CreateList();
end

function DeleteFilter(id)
	FiltersData[id] = nil;
	SaveActiveFilterSet();
	CreateList();
end

function TestFilters()
	local items, resources = Player.GetInventory();
	FilteredItems = {};

	Ui.ClearReviewList();
	for id, data in pairs(items) do
		local itemInfo = Game.GetItemInfoByType(data.item_sdb_id)
		itemInfo.item_sdb_id = data.item_sdb_id;

		if (data.flags and not data.flags.is_equipped and CheckAgainstFilters(itemInfo)) then
			FilteredItems[GetItemNameId(itemInfo)] = 
			{
				sdb_id = data.item_sdb_id,
				item_id = data.item_id;
			};
		end
	end
	
	for id, data in pairs(resources) do
		data.refined.itemTypeId = data.refined.item_sdb_id;
		if (	(data.refined)) then
			FilteredItems[GetItemNameId(data)] = 
			{
				sdb_id = data.refined.itemTypeId
			};
		end
	end

	local count = 0;
	for id, data in pairs(FilteredItems) do
		Ui.AddToReviewList(data.item_id, data.sdb_id, 1, true);

		count = count +1;
	end

	Ui.ReviewListSetCount(count);
	Ui.ShowReview(true, true);
end

function ProcessSalvageQueue(salvageList)
	local summaryStr = "";
	for _,data in pairs(salvageList or salvageQueue) do
		if (uiOpts.printSummary) then
			summaryStr = summaryStr.. unicode.format("%s x %s, ", data.quantity, ChatLib.EncodeItemLink(data.item_sdb_id));
		end
	end

	PrintLoot(unicode.sub(summaryStr, 1, -3));

	isSalvageing = true;
	Debug.Log(tostring(salvageList or salvageQueue));
	local res = TrySalvageItems(salvageList or salvageQueue);
	if (res) then
		salvageQueue = {};
	end
	return res;
end

function LoadReviewList()
	finalisedQueue = {};
	Ui.ClearReviewList();
	
	local count = 0;
	for id, data in pairs(reviewQueue) do
		local num = Player.GetItemCount(data.item_sdb_id);
		if (num > 0) then
			Debug.Log("data.item_guid: ".. tostring(data.item_guid));
			Debug.Log("data.item_sdb_id: "..tostring(data.item_sdb_id));
			Debug.Log("data: "..tostring(data));
			local itemGuidData = data.item_guid and Player.GetItemProperties(data.item_guid) or nil;
			if (data.item_guid == nil or (itemGuidData and itemGuidData.flags.is_equipped == false)) then
				local quant = math.min(data.quantity, num);
				Ui.AddToReviewList(data.item_guid, data.item_sdb_id, quant, false);
				count = count + quant;
			end
		else
			Debug.Log("Invalid item with SDB_ID: "..tostring(data.item_sdb_id));
			reviewQueue[id] = nil;
		end
	end

	Ui.ReviewListSetCount(count);

	Ui.ShowReview(true, false);
end

function ReviewQueueFinilise(add, guid, sdbId, quantity)
	if (add) then
		table.insert(finalisedQueue, {item_guid=guid, item_sdb_id=sdbId, quantity=quantity});
	else
		for id, data in pairs(finalisedQueue) do
			if ((guid and data.item_guid and data.item_guid == guid) or data.item_sdb_id == sdbId) then
				finalisedQueue[id] = nil;
			end
		end
	end

	Debug.Log(tostring(finalisedQueue));
end

function SalvageSelected(isTest)
	if (#finalisedQueue > 0) 	then
		Ui.ShowDialog({
			body = Component.LookupText("SALVAGE_ARE_SURE"):format(#finalisedQueue),
			onYes = function()

				isSalvageing = true;
				if (ProcessSalvageQueue(finalisedQueue)) then
					RemoveSelectedFromReview();
					finalisedQueue = {};

					if not isTest then
						Component.SaveSetting("reviewQueue", reviewQueue);
						LoadReviewList();
					else
						Callback2.FireAndForget(TestFilters, nil, 1);
					end
				end

			end,
			onNo = function()

			end
			});
	end
end

-- Sorry mind going numb now
function KeepSelected()
	if (#finalisedQueue > 0) 	then
		Ui.ShowDialog({
			body = Component.LookupText("KEEP_ARE_SURE"):format(#finalisedQueue),
			onYes = function()

				RemoveSelectedFromReview();

				finalisedQueue = {};
				Component.SaveSetting("reviewQueue", reviewQueue);
				LoadReviewList();
			end,
			onNo = function()

			end
			});
	end
end

function SortFilterList(key, descending)
	local field = HEADER_LOOKUP[key];
	
	table.sort(FiltersData, function (a, b)
		if key == "FLT_LEVEL_RANGE" and a and b then
			if descending then
				return (a ~= nil and (a.levelTo - a.levelFrom) or 0) < (b ~= nil and (b.levelTo - b.levelFrom) or 0);
			else
				return (a ~= nil and (a.levelTo - a.levelFrom) or 0) > (b ~= nil and (b.levelTo - b.levelFrom) or 0);
			end
		else
			if descending then
				return (a ~= nil and a[field] or "") < (b ~= nil and b[field] or "");
			else
				return (a ~= nil and a[field] or "") > (b ~= nil and b[field] or "");
			end
		end
		
		return false;
	end);
	
	SaveActiveFilterSet();
	CreateList();
end

function AddNewFilterSet(name)
	if filterSets == nil then
		filterSets = {};
	end
	
	if not TableHasValue(filterSets, name) then
		table.insert(filterSets, name);
		Component.SaveSetting("filterSets", filterSets);
	else
		Print(Component.LookupText("FILTER_SET_EXISTS"):format(name));
		System.PlaySound(Const.SND.ERROR);
	end
end

function DeleteFilterSet()
	Debug.Log(tostring(#filterSets));
	
	if filterSets and #filterSets == 1 then
		Print(Component.LookupText("FILTER_SET_NO_DELETE"));
		System.PlaySound(Const.SND.ERROR);
	else
		for id, value in pairs(filterSets) do
			if (value == activeFilterSet) then
				filterSets[id] = nil;
			end
		end
		
		FiltersData = nil;
		SaveActiveFilterSet();
		
		SetActiveFilterSet(filterSets[1]);
		
		Component.SaveSetting("filterSets", filterSets);
		Ui.UpdateFilterSets(filterSets);
		Ui.SetActiveFilterSet(name);
	end
end

function SetActiveFilterSet(name)
	if name == NEW_FILTER_SET_ID then
		Ui.ShowTextDialog({
			onYes = function(name)
				AddNewFilterSet(name);
				activeFilterSet = name;
				Ui.UpdateFilterSets(filterSets);
				Ui.SetActiveFilterSet(name);
			end, 
			onNo = function()
				Ui.SetActiveFilterSet(activeFilterSet);
			end
		});
	else
		activeFilterSet = name;
		LoadActiveFilterSet();
		Component.SaveSetting("activeFilterSet", activeFilterSet);
		CreateList();

		-- Just made or migrates, turn on for this char
		if FiltersData == nil then
			FiltersData = {};
		end

		if FiltersData.characters == nil then
			ToggleActiveForChar();
		end
	end

	Ui.UpdateActiveCharButton();
end

--=====================
--		Functions    --
--=====================
function UpdateInvWeight()
    local curr, maxii = Player.GetInventoryWeight();
    inventoryLimts = 
    {
    	current = curr,
    	max = maxii;
    	precent = curr / maxii
    };

    Ui.SetInventoryWeight(inventoryLimts);
end

function CreateList()
	Ui.ClearFilters();
	
	if FiltersData then
		for id, data in pairs(FiltersData) do
			if id ~= "characters" then
				Ui.AddFilterRow(id, data);
			end
		end
	end
end

function CheckAgainstFilters(itemInfo)
	if IsActiveForZone() then
		Debug.Log("ItemInfo:".. tostring(itemInfo));
		Debug.Log("IsActiveForZone: true : "..itemInfo.itemTypeId);

		if IsActiveForChar() then
			for id, data in pairs(FiltersData) do
				if (MatchsFilter(data, itemInfo)) then
					return data;
				end
			end
		end
	end


	return nil;
end

function MatchsFilter(filter, itemInfo)
	Debug.Log("========= Checking against filter =========");
	-- Skip Equipped items, just in case
	if ((itemInfo.dynamic_flags and itemInfo.dynamic_flags.is_equipped) or (itemInfo.flags and not itemInfo.flags.is_salvageable)) then
		Debug.Log("MatchsFilter, earlyied out: "..itemInfo.itemTypeId);
		return;
	end

	-- Early out if we can
	if (CheckWhen(filter, itemInfo) ) then
		Debug.Log("Passed, CheckWhen: "..itemInfo.itemTypeId);

		-- Check Type
		local typeCheck = CheckType(filter, itemInfo);
		if (typeCheck and typeCheck.res == true) then
			Debug.Log("Passed, typeCheck: "..itemInfo.itemTypeId);

			if (CheckFrame(filter, itemInfo) or typeCheck.skipFrameCheck) then
				Debug.Log("Passed, CheckFrame: "..itemInfo.itemTypeId);

				if (CheckLevelRange(filter, itemInfo) or typeCheck.skipLevelCheck) then
					Debug.Log("Passed, CheckLevelRange: "..itemInfo.itemTypeId);

					if (CheckRarity(filter, itemInfo) or typeCheck.skipRarityCheck) then
						Debug.Log("Passed, CheckRarity: "..itemInfo.itemTypeId);

						return true;
					end
				end
			end
		end
	end
end

function CheckWhen(filter, itemInfo)
	if (filter.when == "ON_PICKUP") then
		return true;
	elseif (filter.when == "INV_PCT_FULL" and inventoryLimts.precent > filter.precentFull) then
		return true;
	end
end

function CheckType(filter, itemInfo)
	local typeData = DD_TYPES[filter.typeName];

	-- Some of this is a little messed up atm and inefficient but I want to play it safe instead of well noming on the wrong items
	if (typeData.typeName == "salvage" and (itemInfo.subtitle == "Salvage" or itemInfo.rarity == "salvage" or TableHasValue(typeData.subTypeIds, itemInfo.subTypeId))) then -- Junk Salvage
		return typeData.skips;
	elseif ((filter.typeName == "BATTLEFRAME_CORE") and Game.IsItemOfType(itemInfo.itemTypeId, typeData.subTypeId) and typeData.all) then -- Battleframe Cores
		return typeData.skips;
	elseif ((filter.typeName == "WEAPON_MODULE" or filter.typeName == "ABILITY_MODULE") and Game.IsItemOfType(itemInfo.itemTypeId, typeData.subTypeId) and typeData.module_location == itemInfo.module_location) then -- Modules
		return typeData.skips;
	elseif ((filter.typeName == "ABILITY") and Game.IsItemOfType(itemInfo.itemTypeId, typeData.subTypeId)) then -- Abilitys
		return typeData.skips;
	elseif ((filter.typeName == "PRIMARY_WEAPON" or filter.typeName == "SECONDARY_WEAPON") and Game.IsItemOfType(itemInfo.itemTypeId, typeData.subTypeId)) then -- Weapon's
		return typeData.skips;
	--[[elseif (filter.typeName == "ALL_TYPES" and itemInfo.flags and itemInfo.flags.is_salvageable == true) then -- Anything goes
		return typeData.skips;]]
	end
end

function CheckFrame(filter, itemInfo)
    if (filter.frame == "ANY_FRAME") then
        return true;
    else
		for id, data in ipairs(itemInfo.certifications) do
			local frameData = DD_FRAMES[filter.frame];
			local includeArchtype = config.includeArchtype and frameData.baseFrame;

			if (tonumber(data) == tonumber(frameData.certId) or (includeArchtype and tonumber(data) == tonumber(DD_FRAMES[frameData.baseFrame].certId))) then
				return true;
			end
		end
		
		return fasle;
    end
end

function CheckLevelRange(filter, itemInfo)
    local level = tonumber(itemInfo.required_level);
    return (level == 0 or (level >= tonumber(filter.levelFrom) and level <= tonumber(filter.levelTo))); -- Some junk is level 0
end

function CheckRarity(filter, itemInfo)
	local filterInfo = DD_COLORS[filter.color];
	
    return TableHasValue(filterInfo.raritys, itemInfo.rarity);
end

function PreformFilterAction(filter, itemInfo, guid)
	Debug.Log("PreformFilterAction: "..filter.action);
	
	if (filter.is_test) then
		Debug.Log("Test Item passed filters: " .. tostring(itemInfo.item_sdb_id).." "..itemInfo.name);
		Print("Test Item passed filters: " .. tostring(itemInfo.item_sdb_id).." "..itemInfo.name);
	elseif (filter.action == "SALVAGE") then
		Debug.Log("PreformFilterAction: " .. tostring(guid));
		SalvageAddToQueue(guid, itemInfo.item_sdb_id, itemInfo.lootArgs.quantity);
    	UpdateSalvageQueue();
    elseif (filter.action == "PROMPT") then
		itemInfo.GUID = guid;
    	CreateHudNote(itemInfo);
    elseif (filter.action == "Q_FOR_REVIEW") then
    	AddToReviewQueue(guid, itemInfo.item_sdb_id, itemInfo.lootArgs.quantity);
	end
end

function UpdateSalvageQueue()
	if (not salvageCallBack:Pending()) then
		salvageCallBack:Schedule(salvageQueueFlushDelay);
	else
		salvageCallBack:Reschedule(salvageQueueFlushDelay);
	end
end

-- Move to ui?
function CreateHudNote(itemInfo)
	local HUDNOTE = HudNote.Create()
	HUDNOTE:SetTitle(Component.LookupText("WINDOW_TITE"))
	--HUDNOTE:SetDescription("("..itemInfo.lootArgs.quantity.."x) ".. itemInfo.name .. "\n" .. itemInfo.description)

	local GRP = {GROUP=Component.CreateWidget("PromptBody", Const.REVIEW_LIST_FOSTERING)}
	GRP.ICON = GRP.GROUP:GetChild("icon")
	GRP.ICON:SetUrl(itemInfo.web_icon)
	GRP.TOOLTIP_GROUP = GRP.GROUP:GetChild("tooltip")
	GRP.TOOLTIP = LIB_ITEMS.CreateToolTip(GRP.TOOLTIP_GROUP)
	GRP.TOOLTIP:DisplayInfo(itemInfo)
	local bounds = GRP.TOOLTIP:GetBounds()
	GRP.TOOLTIP_GROUP:SetDims("left:_; top:_; width:"..(bounds.width+12).."; height:"..(bounds.height+16))

	HUDNOTE:SetIconWidget(GRP.ICON)
	HUDNOTE:SetBodyWidget(GRP.TOOLTIP_GROUP)
	HUDNOTE:SetBodyHeight(bounds.height + 22)
	HUDNOTE:SetTags({"scrapii"})

	HUDNOTE:SetPrompt(1, Component.LookupText("DONT_SALVAGE"), function()
			OnsalvagePromptResponce(false, HUDNOTE, GRP, itemInfo);
		end, itemInfo)
	HUDNOTE:SetPrompt(2, Component.LookupText("SALVAGE"), function()
			OnsalvagePromptResponce(true, HUDNOTE, GRP, itemInfo);
		end, itemInfo)

	HUDNOTE:SetTimeout(HUD_NOTE_TIMEOUT, function()
			OnsalvagePromptResponce(false, HUDNOTE, GRP, itemInfo);
		end);
	HUDNOTE:Post()
end

function OnsalvagePromptResponce(salvage, HUDNOTE, GRP, itemInfo)
	if (salvage) then
		SalvageAddToQueue(itemInfo.GUID, itemInfo.item_sdb_id, itemInfo.lootArgs.quantity);
		UpdateSalvageQueue();
	end

	HUDNOTE:Remove();
	Component.RemoveWidget(GRP.GROUP);
end

-- Basicly add the name, level and color together so as to prevent stackable items not stacking
function GetItemNameId(itemInfo)
	return itemInfo.name .. (itemInfo.required_level or "") .. (itemInfo.rarity or itemInfo.refined.rarity);
end

-- Sorting
-- Sort for nice display
function _dataSort(newTbl, oldTbl)
    return (newTbl.sortID < oldTbl.sortID);
end

function GetDataSorted(data)
    local temp = {};
    for id, value in pairs(data) do
        value.id = id;
        table.insert(temp, value);
    end

    table.sort(temp, _dataSort);

    return temp;
end

function IsUserAuthor()
	local _, _, author, _ = Component.GetInfo();
	local name, _, _, _, _ = Player.GetInfo();
	
	return ChatLib.StripArmyTag(name) == author;
end

-- Save each setting separately so it looks a bit nicer in the settings file in case a user wants to edit it the hard way
-- Or another addon need to read a certain value easily
function SaveConfig()
	for id, value in pairs(config) do
		Component.SaveSetting(id, value);
	end
end

function ConfigSaveSetting(id)
	if (config[id] ~= nil) then
		Component.SaveSetting(id, config[id]);
	else
		Debug.Log("Unknown setting: " .. tostring(id));
	end
end

function LoadConfig()
	for id, value in pairs(config) do
		config[id] = Component.GetSetting(id);
	end
end

function LoadSalvageRewards()
	salvageRewards = Component.GetSetting("salvageRewards") or {};
end

function SaveSalvageRewards()
	Component.SaveSetting("salvageRewards", salvageRewards);
end

function AddToCheckList(sdbID, filterData, quantity)
	local data = checkList[tostring(sdbID)];
	if (data) then
		data.quantity = data.quantity + quantity;
	else
		checkList[tostring(sdbID)] = 
		{
			quantity = quantity,
			filterData = filterData
		};
	end
end

function SalvageAddToQueue(guid, sdbId, quantity)
	Debug.Log("SalvageAddToQueue: " .. tostring(guid));
	
	-- Increment the quantity if this item is already here
	local has = false;
	for _, data in pairs(salvageQueue) do
		if (data.item_sdb_id == sdbId) then
			data.quantity = data.quantity + (quantity or 1);
			has = true;
		end
	end

	if (not has) then
		table.insert(salvageQueue, {item_guid=guid, item_sdb_id=sdbId, quantity=quantity or 1});
		Debug.Log("if check, SalvageAddToQueue: " .. tostring({item_guid=guid, item_sdb_id=sdbId, quantity=quantity or 1}));
	end
end

function AddToReviewQueue(guid, sdbId, quantity)
	--[[Debug.Log("Adding item to Review Queue. CID: "..playerID);
	Debug.Log("guid: "..tostring(guid).. "sdbId: "..tostring(sdbId).. "quantity: "..quantity);]]

	-- Increment the quantity if this item is already here
	local has = false;
	for _, data in pairs(reviewQueue) do
		if ((guid and data.item_guid and data.item_guid == guid) or data.item_sdb_id == sdbId) then
			data.quantity = data.quantity + (quantity or 1);
			has = true;
		end
	end

	if (not has) then
		table.insert(reviewQueue, {item_guid=guid, item_sdb_id=sdbId, quantity=quantity or 1});
	end

	Component.SaveSetting("reviewQueue_"..playerID, reviewQueue);
end

function LoadReviewQueue()
	reviewQueue = Component.GetSetting("reviewQueue_"..playerID) or {};
end

function TableHasValue(tbl, id)
	for tbl_id, value in pairs(tbl) do
		if (id == value) then
			return true;
		end
	end
	
	return false;
end

function TrySalvageItems(items)
	local status, err = pcall(function()
		Player.RequestSalvageItems(items);
	end);

	if (err) then
		Debug.Warn("Error: salvaging items: "..tostring(items));
		return false;
	else
		return true;
	end
end

function RemoveSelectedFromReview()
	for id, data in pairs(finalisedQueue) do
		for idx, da in pairs(reviewQueue) do
			if ((da.item_guid and data.item_guid and data.item_guid == da.item_guid) or data.item_sdb_id == da.item_sdb_id) then
				reviewQueue[idx] = nil;
			end
		end
	end
end

function Print(msg)
    ChatLib.Notification({text="[Scrapii] "..msg});
end

function PrintLoot(msg)
	if (uiOpts.printSummary) then
    	Component.GenerateEvent("MY_SYSTEM_MESSAGE", {channel=uiOpts.printSummaryChan, text="[Scrapii] "..msg})
    end
end

function SendWebStats(stats)
	local url = "http://firefall.nyaasync.net/scrapii/stats.php";
	if (not HTTP.IsRequestPending(url)) then -- Not important if we can't send it 
		HTTP.IssueRequest(url, "POST", stats, function(args, err) end);
	else
		Debug.Log("Stats request pending");
	end
end

function GenerateSuportedZonesList()
	local zones = {}

	for _, zone in ipairs(ZONES) do
		zones[zone.zone_id] = true
	end

	return zones
end

function GetZoneList()
	local SuportedZones = GenerateSuportedZonesList()

	HTTP.IssueRequest(System.GetOperatorSetting("ingame_host").."/api/v1/social/static_data.json", "GET", nil, function (args, err)
		--Update the labels in the UI options, these should be localised
		for _,val in pairs(args.zones) do
			if SuportedZones[val.zone_id] then
				if (val.zone_id == 1054) then -- hacky
					InterfaceOptions.UpdateLabel("zone_"..val.zone_id, val.title..": Warfront Raid");
				else
					InterfaceOptions.UpdateLabel("zone_"..val.zone_id, val.title);
				end
			else
				Debug.Warn(unicode.format("Tried to update label for unsupported zone: %s Title: %s", val.zone_id, val.title));
			end
		end
	end);
end

function IsActiveForZone()
	return uiOpts.activeZones[zoneId] == true or (uiOpts.activeZones[zoneId] == nil and uiOpts.salvageInNullZones);
end

function SaveActiveFilterSet()
	Component.SaveSetting("Filter_"..activeFilterSet, FiltersData);
end

function LoadActiveFilterSet()
	FiltersData = Component.GetSetting("Filter_"..activeFilterSet);
end

-- Save the web zone list to use on the next UI reload
function CacheZoneList(zones)
	Component.SaveSetting("zone_list", zones);
end

function GetCachedZoneList()
	return Component.LoadSetting("zone_list");
end

function IsActiveForChar()
	if playerID == nil then
		return;
	end

	local chars = FiltersData and FiltersData.characters or false;
	local isActive = chars and chars[tostring(playerID)]
	return isActive;
end

function ToggleActiveForChar()
	if not FiltersData.characters then
		FiltersData.characters = {};
	end

	FiltersData.characters[tostring(playerID)] = not IsActiveForChar();

	Ui.UpdateActiveCharButton();
	SaveActiveFilterSet();
end