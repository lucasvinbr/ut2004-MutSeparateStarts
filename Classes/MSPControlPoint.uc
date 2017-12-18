//=============================================================================
//ControlPoint.
//is attached to a playerStart, which should change ownership whenever a pawn touches it (and it's takeable)
//=============================================================================
class MSPControlPoint extends xDomPoint;

var PlayerStart controlledStart;

simulated function PostBeginPlay()
{
	Super(DominationPoint).PostBeginPlay();
		
	if (Level.NetMode != NM_Client)
    {
        DomLetter = Spawn(class'XGame.xDomA',self,,Location+EffectOffset,Rotation);
        DomRing = Spawn(class'XGame.xDomRing',self,,Location+EffectOffset,Rotation);
    }

    SetShaderStatus(CNeutralState[0],SNeutralState,CNeutralState[1]);
}

function string GetHumanName()
{
	return "MutSeparateStarts CP";
}

function string GetHumanReadableName()
{
	return "MutSeparateStarts CP";
}

simulated function PostNetReceive()
{
	local byte NewTeam;

    if( !bControllable )
    {
        SetShaderStatus(CDisableState[0],SDisableState,CDisableState[1]);
        NewTeam = 254;
    }
    else if ( ControllingTeam == None )
    {
        SetShaderStatus(CNeutralState[0],SNeutralState,CNeutralState[1]);
        NewTeam = 255;
    }
    else
    {
		if ( ControllingTeam.TeamIndex == 0 )
			SetShaderStatus(CRedState[0],SRedState,CRedState[1]);
		else
			SetShaderStatus(CBlueState[0],SBlueState,CBlueState[1]);
		NewTeam = ControllingTeam.TeamIndex;
		if(controlledStart != None){
			controlledStart.bEnabled = true;
		}
	}
	
	if(controlledStart != None){
		controlledStart.TeamNumber = DefenderTeamIndex;
	}

}

function UpdateStatus()
{
	local Actor A;
	local TeamInfo NewTeam;
	local int OldIndex;

    if ( bControllable && ((ControllingPawn == None) || !ControllingPawn.IsPlayerPawn()) )
    {
		ControllingPawn = None;

        // check if any pawn currently touching
		ForEach TouchingActors(class'Pawn', ControllingPawn)
		{
			if ( ControllingPawn.IsPlayerPawn() )
				break;
			else
				ControllingPawn = None;
		}
	}

    // nothing to do if there is already a controlling team but no controlling pawn
    if (ControllingTeam != None && ControllingPawn == None)
        return;

    // who is the current controlling team of this domination point?
    if (ControllingPawn == None)
		NewTeam = None;
	else
        NewTeam = ControllingPawn.Controller.PlayerReplicationInfo.Team;

	// do nothing if there is no change in the controlling team (and there is a controlling team)
    if ((NewTeam == ControllingTeam) && (NewTeam != None))
		return;

    // for AI, update DefenderTeamIndex
	NetUpdateTime = Level.TimeSeconds - 1;
    OldIndex = DefenderTeamIndex;
	if ( NewTeam == None )
	    DefenderTeamIndex = 255; // ie. "no team" since 0 is a valid team
	else
		DefenderTeamIndex = NewTeam.TeamIndex;
	
	if(controlledStart != None){
		controlledStart.TeamNumber = DefenderTeamIndex;
	}
	
    if ( bControllable && (OldIndex != DefenderTeamIndex) )
		UnrealMPGameInfo(Level.Game).FindNewObjectives(self);

	// otherwise we have a new controlling team, or the domination point is being re-enabled
    ControllingTeam = NewTeam;

    if (ControllingTeam != None)
	{
		PlayAlarm();
	}

    ResetCount();

	if (ControllingTeam == None)
	{
		if(controlledStart != None){
			controlledStart.bEnabled = false;
		}
        // goes dark while untouchable (disabled) after a score
        if (!bControllable)
		{
            LightType = LT_None;
            SetShaderStatus(CDisableState[0],SDisableState,CDisableState[1]);
            if (DomRing != None)
                DomRing.bHidden = true;
        }
        // goes back to white when neutral again
        else if (bControllable)
		{
            // change light emission properties
            LightHue = 255;
            LightBrightness = 128;
		    LightSaturation = 255;
            LightType = LT_SubtlePulse;
            SetShaderStatus(CNeutralState[0],SNeutralState,CNeutralState[1]);
            if (DomRing != None)
            {
                DomRing.bHidden = false;
                DomRing.Skins[0] = class'xDomRing'.Default.NeutralShader;
                DomRing.RepSkin = class'xDomRing'.Default.NeutralShader;
            }
		}
	}
	else{
	
		if(controlledStart != None){
			controlledStart.bEnabled = true;
		}
		
		if (ControllingPawn.Controller.PlayerReplicationInfo.Team.TeamIndex == 0)
		{
			// red team controls it now
			LightType = LT_SubtlePulse;
			LightHue = 0;
			LightBrightness = 255;
			LightSaturation = 128;
			SetShaderStatus(CRedState[0],SRedState,CRedState[1]);
			if (DomRing != None)
			{
				DomRing.bHidden = false;
				DomRing.Skins[0] = class'xDomRing'.Default.RedTeamShader;
				DomRing.RepSkin = class'xDomRing'.Default.RedTeamShader;
			}
		}
		else
		{
			// blue team controls it now
			LightType = LT_SubtlePulse;
			LightHue = 170;
			LightBrightness = 255;
			LightSaturation = 128;
			SetShaderStatus(CBlueState[0],SBlueState,CBlueState[1]);
			if (DomRing != None)
			{
				DomRing.bHidden = false;
				DomRing.Skins[0] = class'xDomRing'.Default.BlueTeamShader;
				DomRing.RepSkin = class'xDomRing'.Default.BlueTeamShader;
			}
		}
	}

    // send the event to trigger related actors
    foreach DynamicActors(class'Actor', A, ControlEvent)
        A.Trigger(self, ControllingPawn);
}

function PlayAlarm()
{
	SetTimer(1.0, false);
	AmbientSound = ControlSound;
}

function Timer()
{
	AmbientSound = None;

    // don't call super here since we don't want it incrementing score!
}

defaultproperties
{
     DestructionMessage="noooo"
     DrawType=DT_None
     StaticMesh=None
     bNoDelete=False
     bDynamicLight=False
     PrePivot=(Z=35.000000)
     bCollideWhenPlacing=False
	RemoteRole=ROLE_SimulatedProxy
	bAlwaysRelevant=True
	bControllable=True
	bTeamControlled=True
	DefenderTeamIndex=255
	bNetNotify=True
}
