using UnityEngine;
using UnityEditor;
using System.Collections;

public class BatchBuild
{
	private static string[] scene_sample = {"Assets/Scenes/Sample.unity"};

	public static void SampleDebugNew()
	{
		Debug.Log("SampleDebugNew");
		if ( BuildiOS(GameType.Sample, false, false)==false ) EditorApplication.Exit(1);
		EditorApplication.Exit(0);
	}
	public static void SampleDebugAppend()
	{
		Debug.Log("SampleDebugAppend");
		if ( BuildiOS(GameType.Sample, false, true)==false  ) EditorApplication.Exit(1);
		EditorApplication.Exit(0);
	}
	public static void SampleReleaseNew()
	{
		Debug.Log("SampleReleaseNew");
		if ( BuildiOS(GameType.Sample, true, false)==false ) EditorApplication.Exit(1);
		EditorApplication.Exit(0);
	}
	public static void SampleReleaseAppend()
	{
		Debug.Log("SampleReleaseAppend");
		if ( BuildiOS(GameType.Sample, true, true)==false  ) EditorApplication.Exit(1);
		EditorApplication.Exit(0);
	}

	private static bool BuildiOS(GameType type, bool release, bool append)
	{
		Debug.Log("Start Build( iOS )");
		BuildOptions opt = BuildOptions.None;
		if (append) {
			opt |= BuildOptions.AcceptExternalModificationsToPlayer;
		}
		if ( release == false ) {
			opt |= BuildOptions.SymlinkLibraries|BuildOptions.Development|BuildOptions.AllowDebugging;
		}

		string[] targetScene = null;
		string dirName = "";
		string bundleIdentifier = "";

		switch (type)			// add this other type
		{
			case GameType.Sample:
				targetScene = scene_sample;
				if (release) {
					dirName = "iOS_Sample_Release";
					bundleIdentifier = "me.seiji.sample.release";
				} else {
					dirName = "iOS_Sample_Debug";					  
					bundleIdentifier = "me.seiji.sample.debug";
				}
				break;
		}
		// PlayerSettings
		PlayerSettings.bundleIdentifier = bundleIdentifier;

		string errorMsg = BuildPipeline.BuildPlayer(targetScene,dirName,BuildTarget.iPhone,opt);
		if ( string.IsNullOrEmpty(errorMsg) ) {
			Debug.Log("Build( iOS ) Success.");
			return true;
		}
		Debug.Log("Build( iOS ) ERROR!");
		Debug.LogError(errorMsg);
		return false;
	}

	enum GameType
	{
		Sample,
	}
}


