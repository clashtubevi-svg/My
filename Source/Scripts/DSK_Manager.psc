Scriptname DSK_Manager extends Quest
{Ядро мода: смерть, потеря душ, костры, Эстус, повышение уровня за души.
 Вешается на квест DSK_MainQuest (Start Game Enabled).}

; ---------------- Формы ----------------
Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto                 ; золото = души
Potion Property DSK_EstusFlask Auto              ; фляга Эстуса (зелье лечения)
MiscObject Property DSK_EstusShard Auto          ; осколок: +1 заряд фляги
Activator Property DSK_BloodstainBase Auto       ; пятно крови (скрипт DSK_Bloodstain)
ObjectReference Property DefaultRespawnMarker Auto ; куда возвращать, пока ни один костёр не зажжён (можно пусто)

GlobalVariable Property DSK_EstusMax Auto        ; текущее макс. число зарядов (старт 3)
GlobalVariable Property DSK_SoulLevel Auto       ; "уровень души" (старт 1)

; ---------------- Сообщения ----------------
Message Property DSK_YouDiedMsg Auto             ; "ВЫ ПОГИБЛИ"
Message Property DSK_SoulsLostMsg Auto           ; "Пятно крови исчезло. Души потеряны."
Message Property DSK_SoulsRecoveredMsg Auto      ; "Души возвращены: %.0f"
Message Property DSK_LevelUpMenu Auto            ; кнопки: Здоровье / Магия / Запас сил / Назад
Message Property DSK_NotEnoughSoulsMsg Auto      ; "Недостаточно душ"
Message Property DSK_EstusUpgradedMsg Auto       ; "Фляга усилена. Зарядов: %.0f"

; ---------------- Настройки ----------------
Int Property MaxEstusCap = 15 Auto
Int Property BaseLevelCost = 200 Auto            ; цена 1-го уровня
Float Property LevelCostGrowth = 1.1 Auto        ; рост цены за уровень
Float Property StatPerLevel = 10.0 Auto          ; сколько даёт один уровень

; ---------------- Состояние ----------------
DSK_Bonfire LastBonfire
DSK_Bloodstain CurrentBloodstain
DSK_BossFogGate CurrentArena
Bool bHandlingDeath = false

; ======================================================================
; Инициализация
; ======================================================================
Function SetupPlayer()
	; Игрок "бессмертен" для движка: вместо Game Over ловим кровотечение (bleedout)
	PlayerRef.GetActorBase().SetEssential(true)
	RefillEstus()
EndFunction

Function OnGameLoaded()
	PlayerRef.GetActorBase().SetEssential(true)
	bHandlingDeath = false
EndFunction

; ======================================================================
; Костры
; ======================================================================
Function SetLastBonfire(DSK_Bonfire akBonfire)
	LastBonfire = akBonfire
EndFunction

Function RestAtBonfire(DSK_Bonfire akBonfire)
	Game.FadeOutGame(true, true, 0.0, 1.0)
	Utility.Wait(1.0)

	PlayerRef.RestoreActorValue("Health", 100000.0)
	PlayerRef.RestoreActorValue("Magicka", 100000.0)
	PlayerRef.RestoreActorValue("Stamina", 100000.0)

	ConsumeEstusShards()
	RefillEstus()
	akBonfire.RespawnEnemies()

	Utility.Wait(0.5)
	Game.FadeOutGame(false, true, 0.0, 1.0)
	Game.RequestSave()
EndFunction

; ======================================================================
; Эстус
; ======================================================================
Function RefillEstus()
	Int have = PlayerRef.GetItemCount(DSK_EstusFlask)
	Int maxE = DSK_EstusMax.GetValueInt()
	If have < maxE
		PlayerRef.AddItem(DSK_EstusFlask, maxE - have, true)
	ElseIf have > maxE
		PlayerRef.RemoveItem(DSK_EstusFlask, have - maxE, true)
	EndIf
EndFunction

Function ConsumeEstusShards()
	If !DSK_EstusShard
		Return
	EndIf
	Int shards = PlayerRef.GetItemCount(DSK_EstusShard)
	If shards <= 0
		Return
	EndIf
	Int maxE = DSK_EstusMax.GetValueInt()
	Int canAdd = MaxEstusCap - maxE
	If canAdd <= 0
		Return
	EndIf
	If shards > canAdd
		shards = canAdd
	EndIf
	PlayerRef.RemoveItem(DSK_EstusShard, shards, true)
	DSK_EstusMax.SetValueInt(maxE + shards)
	DSK_EstusUpgradedMsg.Show(maxE + shards)
EndFunction

; ======================================================================
; Повышение уровня за души
; ======================================================================
Int Function GetLevelCost(Int aiLevel)
	Return (BaseLevelCost * Math.pow(LevelCostGrowth, aiLevel - 1)) as Int
EndFunction

Function OpenLevelUpMenu()
	Bool keepGoing = true
	While keepGoing
		Int level = DSK_SoulLevel.GetValueInt()
		Int cost = GetLevelCost(level)
		Int souls = PlayerRef.GetItemCount(Gold001)
		; текст сообщения: "Уровень: %.0f  Цена: %.0f  Душ: %.0f"
		Int choice = DSK_LevelUpMenu.Show(level, cost, souls)
		If choice >= 0 && choice <= 2
			If souls < cost
				DSK_NotEnoughSoulsMsg.Show()
			Else
				String av = "Health"
				If choice == 1
					av = "Magicka"
				ElseIf choice == 2
					av = "Stamina"
				EndIf
				PlayerRef.RemoveItem(Gold001, cost, true)
				PlayerRef.SetActorValue(av, PlayerRef.GetBaseActorValue(av) + StatPerLevel)
				DSK_SoulLevel.SetValueInt(level + 1)
			EndIf
		Else
			keepGoing = false
		EndIf
	EndWhile
EndFunction

; ======================================================================
; Бои с боссами
; ======================================================================
Function EnterBossFight(DSK_BossFogGate akArena)
	CurrentArena = akArena
EndFunction

Function ExitBossFight(DSK_BossFogGate akArena)
	If CurrentArena == akArena
		CurrentArena = None
	EndIf
EndFunction

; ======================================================================
; Смерть
; ======================================================================
Function HandlePlayerDeath()
	If bHandlingDeath
		Return
	EndIf
	bHandlingDeath = true

	; 1. Старое пятно крови сгорает вместе с душами
	If CurrentBloodstain
		CurrentBloodstain.Disable()
		CurrentBloodstain.Delete()
		CurrentBloodstain = None
		DSK_SoulsLostMsg.Show()
	EndIf

	; 2. Все души остаются на месте гибели
	Int souls = PlayerRef.GetItemCount(Gold001)
	If souls > 0
		PlayerRef.RemoveItem(Gold001, souls, true)
		CurrentBloodstain = PlayerRef.PlaceAtMe(DSK_BloodstainBase) as DSK_Bloodstain
		CurrentBloodstain.StoredSouls = souls
	EndIf

	DSK_YouDiedMsg.Show()
	Utility.Wait(2.0)
	Game.FadeOutGame(true, true, 0.0, 1.5)
	Utility.Wait(1.5)

	; 3. Сброс боя с боссом
	If CurrentArena
		CurrentArena.ResetFight()
		CurrentArena = None
	EndIf

	; 4. Воскрешение у последнего костра
	PlayerRef.StopCombat()
	PlayerRef.RestoreActorValue("Health", 100000.0)
	PlayerRef.RestoreActorValue("Magicka", 100000.0)
	PlayerRef.RestoreActorValue("Stamina", 100000.0)

	If LastBonfire
		PlayerRef.MoveTo(LastBonfire.GetRespawnPoint())
		LastBonfire.RespawnEnemies()
	ElseIf DefaultRespawnMarker
		PlayerRef.MoveTo(DefaultRespawnMarker)
	EndIf
	RefillEstus()

	Utility.Wait(1.0)
	Game.FadeOutGame(false, true, 0.0, 1.5)
	bHandlingDeath = false
EndFunction

Function RecoverBloodstain(DSK_Bloodstain akStain)
	Int souls = akStain.StoredSouls
	PlayerRef.AddItem(Gold001, souls, true)
	DSK_SoulsRecoveredMsg.Show(souls)
	If CurrentBloodstain == akStain
		CurrentBloodstain = None
	EndIf
	akStain.Disable()
	akStain.Delete()
EndFunction
