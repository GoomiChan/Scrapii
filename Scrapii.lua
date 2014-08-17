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
require "lib/lib_ErrorDialog";
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
require "./data";
require "./Ui";
-- Just include them all why don't I

--=====================
--		Constants    --
--=====================
HUD_NOTE_TIMEOUT = 100;
salvageQueueFlushDelay = 7;

--=====================
--		Varables     --
--=====================
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
	processRewards = true
};

-- Filter related configes
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

--=====================
--      Events       --
--=====================
function OnComponentLoad(args)	
	LoadSalvageRewards();
    Ui.Init();
    LoadConfig();
    LoadReviewQueue();

	Ui.UpdateProfitsTootip(salvageRewards);

	FiltersData = Component.GetSetting("FiltersData") or {};
	
	CreateList();

	salvageCallBack:Bind(ProcessSalvageQueue);
end

function OnPlayerReady(args)
	c_cid = Player.GetTargetId();

	-- See Mavoc I do listen, sometimes
	Debug.EnableLogging(IsUserAuthor() or uiOpts.enableDebug);
    UpdateInvWeight();

    Debug.Log(tostring(Game.GetItemInfoByType(102768)));
end

function OnLootCollected(args)
	if (args.lootedToId ~= c_cid and not uiOpts.processLoot) then
		return;
	end

    local itemTypeId = args.itemTypeId;
    local info = Game.GetItemInfoByType(itemTypeId);

    if (info.flags and info.flags.is_salvageable) then
	    info.item_sdb_id = itemTypeId;
	    info.lootArgs = args;

		local result = CheckAgainstFilters(info);
	    if (result) then
	    	PreformFilterAction(result, info);
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
	if (uiOpts.processRewards) then
		for id, data in pairs(args.rewards) do
			local itemTypeId = data.itemTypeId;
		    local info = Game.GetItemInfoByType(itemTypeId);

		    if (info.flags and info.flags.is_salvageable) then
			    info.item_sdb_id = itemTypeId;
			    info.lootArgs = args;

				local result = CheckAgainstFilters(info);
			    if (result) then
			    	PreformFilterAction(result, info);
			    end
			end
		end
	end
end

--=====================
--		Callacks     --
--=====================
function OnClose(args)
    Ui.Show(false);
end

function OnCloseRP(args)
	Ui.ShowReview(false);
end

-- Called from the UI
function CreateNewFilter(data)
    table.insert(FiltersData, data);
	Component.SaveSetting("FiltersData", FiltersData);
	Ui.AddFilterRow(#FiltersData, data);
end

function EditFilter(id, data)
	FiltersData[id] = data;
	Component.SaveSetting("FiltersData", FiltersData);
	CreateList();
end

function DeleteFilter(id)
	FiltersData[id] = nil;
	Component.SaveSetting("FiltersData", FiltersData);
	CreateList();
end

function TestFilters()
	local items, resources = Player.GetInventory();
	FilteredItems = {};

	Ui.ClearReviewList();
	for id, data in pairs(items) do
		local itemInfo = Game.GetItemInfoByType(data.item_sdb_id)
		itemInfo.item_sdb_id = data.item_sdb_id;
		if (CheckAgainstFilters(itemInfo)) then
			FilteredItems[GetItemNameId(itemInfo)] = data.item_sdb_id;
		end
	end
	
	for id, data in pairs(resources) do
		if (CheckAgainstFilters(data.refined)) then
			FilteredItems[GetItemNameId(data)] = data.itemTypeId;
		end
	end

	local count = 0;
	for id, data in pairs(FilteredItems) do
		Ui.AddToReviewList(nil, data, 1, true);

		count = count +1;
	end

	Ui.ReviewListSetCount(count);
	Ui.ShowReview(true, true);
end

function ProcessSalvageQueue()
	-- Reslove any guid that we need to get
	local summaryStr = "";
	local items, resources = Player.GetInventory();
	for _,data in pairs(salvageQueue) do
		if (data.item_guid == "need") then
			Debug.Log("Resloving guid for " .. tostring(data.item_sdb_id));
			data.item_guid = MatchSdbId(data.item_sdb_id, items);
		end

		if (uiOpts.printSummary) then
			summaryStr = summaryStr.. unicode.format("%s x %s, ", data.quantity, ChatLib.EncodeItemLink(data.item_sdb_id));
		end
	end

	PrintLoot(unicode.sub(summaryStr, 1, -3));

	isSalvageing = true;
	Debug.Log(tostring(salvageQueue));
	Player.RequestSalvageItems(salvageQueue);
	salvageQueue = {};
end

function LoadReviewList()
	finalisedQueue = {};
	Ui.ClearReviewList();
	
	local count = 0;
	for id, data in pairs(reviewQueue) do
		Ui.AddToReviewList(data.item_guid, data.item_sdb_id, data.quantity, false);
		count = count + data.quantity;
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

function SalvageSelected()
	if (#finalisedQueue > 0) 	then
		Ui.ShowDialog({
			body = Component.LookupText("SALVAGE_ARE_SURE"):format(#finalisedQueue),
			onYes = function()

				isSalvageing = true;
				if (TrySalvageItems(finalisedQueue)) then
					RemoveSelectedFromReview();
					finalisedQueue = {};
					Component.SaveSetting("reviewQueue", reviewQueue);
					LoadReviewList();
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
	
	for id, data in pairs(FiltersData) do
		Ui.AddFilterRow(id, data);
	end
end

function CheckAgainstFilters(itemInfo)
	for id, data in pairs(FiltersData) do
		if (MatchsFilter(data, itemInfo)) then
			return data;
		end
	end

	return nil;
end

function MatchsFilter(filter, itemInfo)
	-- Skip Equiped items, jsut incase
	if ((itemInfo.dynamic_flags and itemInfo.dynamic_flags.is_equipped) or (itemInfo.flags and not itemInfo.flags.is_salvageable)) then
		return;
	end

	-- Early out if we can
	if (CheckWhen(filter, itemInfo) ) then
		-- Check Type
		local typeCheck = CheckType(filter, itemInfo);
		if (typeCheck and typeCheck.res == true) then
			if (CheckFrame(filter, itemInfo) or typeCheck.skipFrameCheck) then
				if (CheckLevelRange(filter, itemInfo)) then
					if (CheckRarity(filter, itemInfo) or typeCheck.skipRarityCheck) then
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
	
	if (typeData.typeName == "salvage" and (itemInfo.subtitle == "Salvage" or itemInfo.rarity == "salvage" or TableHasValue(typeData.subTypeIds, itemInfo.subTypeId))) then -- Junk Salvage
		return typeData.skips;
	elseif (typeData.typeName == "frame_module" and itemInfo.type == "frame_module" and typeData.all) then -- Battleframe Cores
		return typeData.skips;
	elseif (typeData.typeName == "module" and itemInfo.type == "item_module" and typeData.module_location == itemInfo.module_location) then -- Modules
		return typeData.skips;
	elseif (typeData.typeName == "ablity"  and itemInfo.type == "ability_module") then -- Ablitys
		return typeData.skips;
	elseif ((typeData.typeName == "weapon" and itemInfo.type == "weapon") and (itemInfo.slotIdx and itemInfo.slotIdx == typeData.slotIdx)) then -- Weapon's
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
			local info = Game.GetCertificationInfo(data);
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

function PreformFilterAction(filter, itemInfo)
	local guid = nil;
	if (filter.typeName == "PRIMARY_WEAPON" or filter.typeName == "SECONDARY_WEAPON" or filter.typeName == "ABILITY" or filter.typeName == "BATTLEFRAME_CORE") then -- ABILITY and BATTLEFRAME_CORE may not need a guid, not sure yet
		guid = "need";
		itemInfo.GUID = guid;
	end

	if (filter.action == "SALVAGE") then
		SalvageAddToQueue(guid, itemInfo.item_sdb_id, itemInfo.lootArgs.quantity);
    	UpdateSalvageQueue();
    elseif (filter.action == "PROMPT") then
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

	HUDNOTE:SetPrompt(1, Component.LookupText("SALVAGE"), function()
			OnsalvagePromptResponce(true, HUDNOTE, GRP, itemInfo);
		end, itemInfo)
	HUDNOTE:SetPrompt(2, Component.LookupText("DONT_SALVAGE"), function()
			OnsalvagePromptResponce(false, HUDNOTE, GRP, itemInfo)
;		end, itemInfo)

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

function MatchSdbId(sdb_id, items)
	Debug.Log("=========== MatchSdbId ===========");

	for id, data in pairs(items) do
		if (tostring(sdb_id) == tostring(data.item_sdb_id) and data.flags.is_new and data.flags.is_salvageable and not data.flags.is_bound and data.item_id) then -- sdb_id matchs, is new, salvagable, not bound and has a guid
			Debug.Log("=========== MatchSdbId first check passed ===========");

			local item_id = data.item_id;
			local playerItemInfo = Player.GetItemInfo(item_id);

			-- Some extra safetly checks, check that it has no mods, isn't equiped, isn't bound. I reallllllllly don't want to nom on the wrong item :s
			if ((playerItemInfo.dynamic_flags and playerItemInfo.dynamic_flags.is_equipped == false) --[[and (playerItemInfo.slotted_modules and #playerItemInfo.slotted_modules == 0)]]) then

				Debug.Log(data.name..": "..tostring(data.item_id).." : "..tostring(data.item_sdb_id).." : "..tostring(Player.GetItemCount(data.item_sdb_id)));
				Debug.Log(tostring(data));
				Debug.Log(tostring(playerItemInfo));

				return item_id;
			end

		end
	end
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

-- Save each setting sepratly so it looks a bit nicer in the settings file incase a user wants to edit it the hardway
-- Or another addon need to read a certan value easly
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

function SalvageAddToQueue(guid, sdbId, quantity)
	-- Incremnt the quanity if this item is already here
	local has = false;
	for _, data in pairs(salvageQueue) do
		if (data.item_sdb_id == sdbId) then
			data.quantity = data.quantity + (quantity or 1);
			has = true;
		end
	end

	if (not has) then
		table.insert(salvageQueue, {item_guid=guid, item_sdb_id=sdbId, quantity=quantity or 1});
	end
end

function AddToReviewQueue(guid, sdbId, quantity)
	-- Delay by a few seconds to ensure it got added to the inventory
	Callback2.FireAndForget(function()
		local items, resources = Player.GetInventory();

		-- reslove it now becasue who knows how long this will sit in the review queue
		if (guid == "need") then
			Debug.Log("Resloving guid for " .. tostring(sdbId));
			guid = MatchSdbId(sdbId, items);
		end

		-- Incremnt the quanity if this item is already here
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

		Component.SaveSetting("reviewQueue", reviewQueue);
	end, nil, 5);
end

function LoadReviewQueue()
	reviewQueue = Component.GetSetting("reviewQueue") or {};
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
	if (not HTTP.IsRequestPending()) then -- Not imporant if we can't send it 
		HTTP.IssueRequest("http://firefall.nyaasync.net/scrapii/stats.php", "POST", stats, function(args, err) end);
	else
		Debug.Log("Stats request pending");
	end
end