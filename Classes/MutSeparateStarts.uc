class MutSeparateStarts extends Mutator;

var config float extraSpawnsRadius;
var config int numControlPoints;

var localized string radiusEntryLabel, radiusEntryDesc, numCPsEntryLabel, numCPsEntryDesc;

var PlayerStart startOne, startTwo;
var array< PlayerStart > playerStarts;
var array< MSPControlPoint > createdCPs;

function PreBeginPlay()
{
	local int i, j, trueNumCPs;
	local NavigationPoint L;
		
	local float biggestDist, curEvalDist, CPsDist;
	
	biggestDist = 0;
	
	//force gametypes like teamDM to consider the playerstarts' teamNumber attribute
	if ( Level != None && Level.Game != None && Level.Game.IsA('TeamGame') ){
		TeamGame( Level.Game ).bSpawnInTeamArea = true;
	}
	
	//getting all playerstarts... (we deactivate all of them and reactivate the farthest only)
	for(L=Level.NavigationPointList; L!=none; L=L.NextNavigationPoint){
		if(PlayerStart(L) != none){
			playerStarts.insert(0, 1);
			playerStarts[0] = PlayerStart(L);
			PlayerStart(L).bEnabled=False;
		}
	}
	
	//find and set the farthest as the activated spawns!
	for(i = 0; i < playerStarts.Length; i++){
		for(j = i+1; j < playerStarts.Length; j++){
			curEvalDist = VSize(playerStarts[i].Location - playerStarts[j].Location);
			if(curEvalDist > biggestDist){
				biggestDist = curEvalDist;
				startOne = playerStarts[i];
				startTwo = playerStarts[j];
			}
		}
	}
	
	SetTeamAndActivate(startOne, 0);
	SetTeamAndActivate(startTwo, 1);

	//extra playerStarts inside the provided radius
	if(extraSpawnsRadius > 0){
		for(i = 0; i < playerStarts.Length; i++){
			if(playerStarts[i].bEnabled){
				continue;
			}
			curEvalDist = VSize(startOne.Location - playerStarts[i].Location);
			if(curEvalDist < extraSpawnsRadius){
				SetTeamAndActivate(playerStarts[i], 0);
			}else{
				curEvalDist = VSize(startTwo.Location - playerStarts[i].Location);
				if(curEvalDist < extraSpawnsRadius){
					SetTeamAndActivate(playerStarts[i], 1);
				}
			}
		}
	}
	
	//control points!
	if(numControlPoints > 0){
		//cps distance should consider the amount of cps desired.
		//the cps amount should also not be greater than the amount of playerStarts!
		trueNumCPs = Min(numControlPoints, playerStarts.Length - 2);
		if(trueNumCPs > 0){
			CPsDist = biggestDist / (trueNumCPs + 1.0);
		
			for(i = 0; i < trueNumCPs; i++){
				//alternate between considering distances from start one and two
				if(i % 2 == 0){
					PutCPOnPlayerStart(startOne, biggestDist, CPsDist / Max(i / 2, 1));
				}else{
					PutCPOnPlayerStart(startTwo, biggestDist, CPsDist / Max(i / 2, 1));
				}
			}
		}
		
	}
	Super.PreBeginPlay();
}

function SetTeamAndActivate(PlayerStart p, int desiredTeam){
	p.bEnabled = true;
	p.TeamNumber = desiredTeam;
}

function PutCPOnPlayerStart(PlayerStart referencePS, float veryBigDist, float desiredDist){
	local int i;
	local float curEvalDelta, nicestDelta;
	local PlayerStart nicestPS;
	
	nicestDelta = veryBigDist;
	
	for(i = 0; i < playerStarts.Length; i++){
		if(playerStarts[i] == startOne || playerStarts[i] == startTwo || IsPlayerStartAlreadyUsedByCP(playerStarts[i])){
			continue;
		}
		curEvalDelta = Abs(VSize(referencePS.Location - playerStarts[i].Location) - desiredDist);
		if(curEvalDelta < nicestDelta){
			nicestPS = playerStarts[i];
			nicestDelta = curEvalDelta;
		}
	}
	
	if(nicestPS != none){
		SpawnCP(nicestPS);
	}
}

function SpawnCP(PlayerStart attachedStart){
	local MSPControlPoint newCP;
	
	newCP = Spawn(class'MutSeparateStarts.MSPControlPoint',,,attachedStart.Location);
	if(newCP != none){
		newCP.controlledStart = attachedStart;
		createdCPs.insert(0, 1);
		createdCPs[0] = newCP;
	}
	
}

function bool IsPlayerStartAlreadyUsedByCP(PlayerStart theStart){
	local int i;
		
	for(i = 0; i < createdCPs.Length; i++){
		if(createdCPs[i].controlledStart == theStart){
			return true;
		}
	}
	
	return false;
}

// The function used to obtain the text that will be displayed within the
// config window.
static function string GetDisplayText(string PropName) {
	// The value of PropName passed to the function should match the variable name
	// being configured.
	switch(PropName){
		case "extraSpawnsRadius":
			return default.radiusEntryLabel;
		case "numControlPoints":
			return default.numCPsEntryLabel;
	}
	//return Super.GetDisplayText(PropName);
}
 
// The function used to obtain the "hint" text that is displayed at the bottom
// of the config window.
static event string GetDescriptionText(string PropName) {
	// The value of PropName passed to the function should match the variable name
	// being configured.
	switch(PropName){
		case "extraSpawnsRadius":
			return default.radiusEntryDesc;
		case "numControlPoints":
			return default.numCPsEntryDesc;
	}
	return Super.GetDescriptionText(PropName);
}

static function FillPlayInfo(PlayInfo PlayInfo)
{
	Super.FillPlayInfo(PlayInfo);

	PlayInfo.AddSetting(default.RulesGroup, "extraSpawnsRadius", GetDisplayText("extraSpawnsRadius"), 0, 0, "Text",   "8;0.0:99999.9");
	PlayInfo.AddSetting(default.RulesGroup, "numControlPoints", GetDisplayText("numControlPoints"), 0, 0, "Text",   "8;0:99");
}

defaultproperties
{
	GroupName="Spawn"
	FriendlyName="Isolate Player Starts"
	Description="In two-team matches, makes teams start as far away from each other as possible. May also spawn control points, which activate another spawn point for the team that controls it"
	radiusEntryLabel="Additional Player Starts Radius"
	radiusEntryDesc="Any player start found within this radius from one of the farthest will be used by the respective team"
	numCPsEntryLabel="Control Points"
	numCPsEntryDesc="Sets the amount of control points that will be placed in the map. The mutator will attempt to place the CPs so that each one has the same distance to each other"
	extraSpawnsRadius=512.0
	numControlPoints=0
}
