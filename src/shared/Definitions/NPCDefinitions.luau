--!strict
--[[
	NPCDefinitions.luau
	Authoritative definitions for all frontier NPCs, archetypes, dialogue trees, and patrol routes.
]]

local NPCTypes = require(script.Parent.Parent.Types.NPCTypes)

type NPCDefinition = NPCTypes.NPCDefinition

local NPCDefinitions: { [string]: NPCDefinition } = {
	["npc_sheriff"] = {
		Id = "npc_sheriff",
		DisplayName = "Sheriff Cooper",
		RoleTitle = "Town Sheriff",
		Archetype = "Sheriff",
		InitialNodeId = "node_root",
		InteractionDistance = 14,
		WanderRadius = 6,
		PatrolWaypoints = {
			Vector3.new(35, 3, -15),
			Vector3.new(42, 3, -20),
			Vector3.new(35, 3, -15),
		},
		DefaultDialogueTree = {
			["node_root"] = {
				NodeId = "node_root",
				Text = "Keep your hands where I can see 'em, stranger. Law and order runs this frontier now. What's your business?",
				Choices = {
					{
						Text = "Got any bounties or trouble I can help with, Sheriff?",
						NextNodeId = "node_quest_offer",
						Action = "None",
					},
					{
						Text = "I found your stolen pocket watch!",
						NextNodeId = "node_quest_complete",
						Action = "CompleteQuest",
						ActionPayload = "quest_sheriff_request",
						RequirementQuestId = "quest_sheriff_request",
					},
					{
						Text = "Just paying my respects. Stay safe, Sheriff.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_quest_offer"] = {
				NodeId = "node_quest_offer",
				Text = "Matter of fact, yes. A gang of desert bandits stole my heirloom gold pocket watch. Stashed it out by the old desert outpost. Retrieve it, and I'll pin a Deputy Star on you.",
				Choices = {
					{
						Text = "I'll track it down for you, Sheriff.",
						NextNodeId = nil,
						Action = "AcceptQuest",
						ActionPayload = "quest_sheriff_request",
					},
					{
						Text = "Sounds too dangerous for me.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_quest_complete"] = {
				NodeId = "node_quest_complete",
				Text = "My grandfather's watch! By thunder, you're true grit, partner. Here's your coin reward and a genuine Deputy Star. Wear it with pride.",
				Choices = {
					{
						Text = "Much obliged, Sheriff.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
		},
	},

	["npc_merchant"] = {
		Id = "npc_merchant",
		DisplayName = "Silas Vance",
		RoleTitle = "General Store Trader",
		Archetype = "Merchant",
		InitialNodeId = "node_root",
		InteractionDistance = 14,
		WanderRadius = 4,
		PatrolWaypoints = {
			Vector3.new(-30, 3, -10),
			Vector3.new(-26, 3, -12),
		},
		DefaultDialogueTree = {
			["node_root"] = {
				NodeId = "node_root",
				Text = "Welcome to Silas's Trading Post! Finest picks, hats, and dried goods west of the Mississippi.",
				Choices = {
					{
						Text = "Let me browse your trading wares.",
						NextNodeId = nil,
						Action = "OpenShop",
						ActionPayload = "general_store",
					},
					{
						Text = "Did you mention something about lost supplies?",
						NextNodeId = "node_quest_supplies",
						Action = "None",
					},
					{
						Text = "I brought the supply crates you asked for!",
						NextNodeId = "node_complete_supplies",
						Action = "CompleteQuest",
						ActionPayload = "quest_missing_supplies",
						RequirementQuestId = "quest_missing_supplies",
					},
					{
						Text = "Rancher Jesse sent me to deliver his trade ledger.",
						NextNodeId = "node_complete_delivery",
						Action = "CompleteQuest",
						ActionPayload = "quest_merchant_delivery",
						RequirementQuestId = "quest_merchant_delivery",
					},
					{
						Text = "Just looking around, Silas. Thanks.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_quest_supplies"] = {
				NodeId = "node_quest_supplies",
				Text = "Aye! A supply cart overturned on the rocky trails. 5 wooden crates rolled all across town. Bring them back safely, and I'll pay you handsomely in cold gold and supplies.",
				Choices = {
					{
						Text = "Consider it done. I'll round them up.",
						NextNodeId = nil,
						Action = "AcceptQuest",
						ActionPayload = "quest_missing_supplies",
					},
					{
						Text = "Maybe later.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_complete_supplies"] = {
				NodeId = "node_complete_supplies",
				Text = "Every crate accounted for! You saved my inventory, partner. Here's your coin reward and a sturdy leather canteen.",
				Choices = {
					{
						Text = "Pleasure doing business with you.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_complete_delivery"] = {
				NodeId = "node_complete_delivery",
				Text = "Ah, Jesse's ledger! Good to see his numbers match up. Here is a hefty pouch of coins and a raw gold nugget for your trouble.",
				Choices = {
					{
						Text = "Glad I could help.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
		},
	},

	["npc_bartender"] = {
		Id = "npc_bartender",
		DisplayName = "Cole Holloway",
		RoleTitle = "Dusty Spur Barkeep",
		Archetype = "QuestGiver",
		InitialNodeId = "node_root",
		InteractionDistance = 14,
		WanderRadius = 3,
		DefaultDialogueTree = {
			["node_root"] = {
				NodeId = "node_root",
				Text = "Wipe the trail dust off your boots! Welcome to the Dusty Spur. What's your pleasure, traveller?",
				Choices = {
					{
						Text = "I'm new in town. What's worth checking out?",
						NextNodeId = "node_tour_offer",
						Action = "None",
					},
					{
						Text = "I've toured the whole town and visited every landmark!",
						NextNodeId = "node_tour_complete",
						Action = "CompleteQuest",
						ActionPayload = "quest_frontier_explorer",
						RequirementQuestId = "quest_frontier_explorer",
					},
					{
						Text = "Just enjoying the piano tunes. Carry on.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_tour_offer"] = {
				NodeId = "node_tour_offer",
				Text = "You'll want to see our four landmarks: this Saloon, Sheriff Cooper's office, Silas's General Store, and the town Stables. Scout all four, and I'll treat you to some fine frontier remedies.",
				Choices = {
					{
						Text = "Sounds like a great way to learn the ropes. I'm on it!",
						NextNodeId = nil,
						Action = "AcceptQuest",
						ActionPayload = "quest_frontier_explorer",
					},
					{
						Text = "I prefer staying inside.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_tour_complete"] = {
				NodeId = "node_tour_complete",
				Text = "Now you know every corner of this frontier town! Here's a pouch of coins and some soothing herbal salves for the road.",
				Choices = {
					{
						Text = "Thanks, Cole!",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
		},
	},

	["npc_stablemaster"] = {
		Id = "npc_stablemaster",
		DisplayName = "Rancher Jesse",
		RoleTitle = "Stable Master",
		Archetype = "StableMaster",
		InitialNodeId = "node_root",
		InteractionDistance = 14,
		WanderRadius = 5,
		DefaultDialogueTree = {
			["node_root"] = {
				NodeId = "node_root",
				Text = "Watch your step around the horses. What can old Jesse do for you today, friend?",
				Choices = {
					{
						Text = "Got any errands or work around the stables?",
						NextNodeId = "node_errand_offer",
						Action = "None",
					},
					{
						Text = "Beautiful horses you've got here.",
						NextNodeId = "node_horses",
						Action = "None",
					},
					{
						Text = "Just passing by. Take care.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_errand_offer"] = {
				NodeId = "node_errand_offer",
				Text = "Actually, yes! I've wrapped up our horse-shoeing and hay trade records in this ledger. Deliver it over to Silas at the General Store for me, will you?",
				Choices = {
					{
						Text = "I'll take it over to Silas right away.",
						NextNodeId = nil,
						Action = "AcceptQuest",
						ActionPayload = "quest_merchant_delivery",
					},
					{
						Text = "I'm heading the other direction right now.",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
			["node_horses"] = {
				NodeId = "node_horses",
				Text = "Fastest thoroughbreds and toughest desert mustangs in the territory. Treat 'em with respect and they'll never let you down.",
				Choices = {
					{
						Text = "Good to know!",
						NextNodeId = nil,
						Action = "None",
					},
				},
			},
		},
	},
}

local NPCDefinitionsModule = {}

function NPCDefinitionsModule.Get(npcId: string): NPCDefinition?
	return NPCDefinitions[npcId]
end

function NPCDefinitionsModule.GetAll(): { [string]: NPCDefinition }
	return NPCDefinitions
end

return NPCDefinitionsModule
