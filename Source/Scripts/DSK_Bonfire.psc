Scriptname DSK_Bonfire extends ObjectReference
{Костёр. Вешается на ссылку-активатор (Activator) в мире.
 Первая активация зажигает костёр, дальше открывается меню: Отдохнуть / Повысить уровень / Уйти.}

DSK_Manager Property Manager Auto
ObjectReference Property RespawnPoint Auto        ; XMarkerHeading рядом с костром (пусто = сам костёр)
ObjectReference Property LitFX Auto               ; огонь/свет, Initially Disabled (можно пусто)
Actor[] Property EnemiesToRespawn Auto            ; враги, которые оживают при отдыхе

Message Property DSK_BonfireLitMsg Auto           ; "КОСТЁР ЗАЖЖЁН"
Message Property DSK_BonfireMenu Auto             ; кнопки: 0 Отдохнуть, 1 Повысить уровень, 2 Уйти
Message Property DSK_CannotRestMsg Auto           ; "Нельзя отдыхать, когда рядом враги"

Bool Property IsLit = false Auto Hidden

Event OnActivate(ObjectReference akActionRef)
	Actor player = Game.GetPlayer()
	If akActionRef != player
		Return
	EndIf
	If player.IsInCombat()
		DSK_CannotRestMsg.Show()
		Return
	EndIf

	If !IsLit
		IsLit = true
		If LitFX
			LitFX.Enable(true)
		EndIf
		DSK_BonfireLitMsg.Show()
	EndIf
	Manager.SetLastBonfire(self)

	Bool keepGoing = true
	While keepGoing
		Int choice = DSK_BonfireMenu.Show()
		If choice == 0
			Manager.RestAtBonfire(self)
		ElseIf choice == 1
			Manager.OpenLevelUpMenu()
		Else
			keepGoing = false
		EndIf
	EndWhile
EndEvent

ObjectReference Function GetRespawnPoint()
	If RespawnPoint
		Return RespawnPoint
	EndIf
	Return self
EndFunction

Function RespawnEnemies()
	If !EnemiesToRespawn
		Return
	EndIf
	Int i = 0
	While i < EnemiesToRespawn.Length
		Actor a = EnemiesToRespawn[i]
		If a
			If a.IsDead()
				a.Resurrect()
			EndIf
			a.StopCombat()
			a.RestoreActorValue("Health", 100000.0)
			a.MoveToMyEditorLocation()
			a.EvaluatePackage()
		EndIf
		i += 1
	EndWhile
EndFunction
