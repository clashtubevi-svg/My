Scriptname DSK_PlayerAlias extends ReferenceAlias
{Алиас игрока в DSK_MainQuest. Ловит "смерть" (кровотечение) и загрузку сохранения.}

DSK_Manager Property Manager Auto

Event OnInit()
	Manager.SetupPlayer()
EndEvent

Event OnPlayerLoadGame()
	Manager.OnGameLoaded()
EndEvent

Event OnEnterBleedout()
	Manager.HandlePlayerDeath()
EndEvent
