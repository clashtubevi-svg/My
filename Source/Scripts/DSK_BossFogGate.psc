Scriptname DSK_BossFogGate extends ObjectReference
{Туманная стена перед ареной босса. Вешается на ссылку-активатор с коллизией.
 Активация: игрок проходит внутрь, выходы закрываются, начинается бой.
 Победа: туман исчезает. Смерть игрока: бой сбрасывается.}

DSK_Manager Property Manager Auto
DSK_Boss Property Boss Auto                    ; босс, в CK отметить Initially Disabled
ObjectReference Property InsideMarker Auto     ; XMarkerHeading сразу за туманом
ObjectReference[] Property ExtraFogWalls Auto  ; туман на других выходах (Initially Disabled)
MusicType Property BossMusic Auto              ; напр. MUSCombatBoss
Message Property DSK_BossDefeatedMsg Auto      ; "ВЕЛИКИЙ ВРАГ ПОВЕРЖЕН"
Message Property DSK_BossIntroMsg Auto         ; имя босса (можно пусто)
Form Property BossReward Auto                  ; оружие/душа босса и т.п. (можно пусто)
Int Property SoulReward = 5000 Auto

Bool Property Defeated = false Auto Hidden
Bool FightActive = false

Event OnActivate(ObjectReference akActionRef)
	Actor player = Game.GetPlayer()
	If akActionRef != player || Defeated || FightActive
		Return
	EndIf
	player.MoveTo(InsideMarker)
	StartFight()
EndEvent

Function StartFight()
	FightActive = true
	Manager.EnterBossFight(self)
	SetExtraWalls(true)
	Boss.Arena = self
	Boss.Enable()
	Boss.EvaluatePackage()
	Boss.StartCombat(Game.GetPlayer())
	If BossMusic
		BossMusic.Add()
	EndIf
	If DSK_BossIntroMsg
		DSK_BossIntroMsg.Show()
	EndIf
EndFunction

Function OnBossDefeated()
	If !FightActive
		Return
	EndIf
	FightActive = false
	Defeated = true
	Manager.ExitBossFight(self)
	If BossMusic
		BossMusic.Remove()
	EndIf
	Utility.Wait(2.0)
	DSK_BossDefeatedMsg.Show()
	Actor player = Game.GetPlayer()
	If SoulReward > 0
		player.AddItem(Manager.Gold001, SoulReward)
	EndIf
	If BossReward
		player.AddItem(BossReward, 1)
	EndIf
	SetExtraWalls(false)
	Disable(true)
EndFunction

; Вызывается менеджером при гибели игрока во время боя
Function ResetFight()
	If !FightActive
		Return
	EndIf
	FightActive = false
	If BossMusic
		BossMusic.Remove()
	EndIf
	Boss.ResetBoss()
	SetExtraWalls(false)
EndFunction

Function SetExtraWalls(Bool abEnable)
	If !ExtraFogWalls
		Return
	EndIf
	Int i = 0
	While i < ExtraFogWalls.Length
		If ExtraFogWalls[i]
			If abEnable
				ExtraFogWalls[i].Enable()
			Else
				ExtraFogWalls[i].Disable()
			EndIf
		EndIf
		i += 1
	EndWhile
EndFunction
