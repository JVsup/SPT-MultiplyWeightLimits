using Spectre.Console;
using SPTarkov.Common.Models.Logging;
using SPTarkov.DI.Annotations;
using SPTarkov.Server.Core.DI;
using SPTarkov.Server.Core.Helpers.Server;
using SPTarkov.Server.Core.Models.Spt.Mod;
using SPTarkov.Server.Core.Models.Spt.Tables;

namespace SPT.MultiplyWeightLimits;

public sealed record ModMetadata : IModMetadata
{
    public string ModGuid { get; init; } = "spt.multiplyweightlimits";
    public string Name { get; init; } = "SPT Multiply Weight Limits";
    public string Author { get; init; } = "JVsup";
    public List<string>? Contributors { get; init; }
    public SemanticVersioning.Version Version { get; init; } = new("4.1.0");
    public SemanticVersioning.Range SptVersion { get; init; } = new("~4.1.0");
    public List<string>? Incompatibilities { get; init; }
    public Dictionary<string, SemanticVersioning.Range>? ModDependencies { get; init; }
    public string? Url { get; init; } = "https://github.com/JVsup/SPT-MultiplyWeightLimits";
    public string License { get; init; } = "MIT";
    public bool HasPrepatcher { get; init; }
}

[Injectable(TypePriority = OnLoadOrder.PostLoad + 1)]
public sealed class MultiplyWeightLimits(
    ISptLogger<MultiplyWeightLimits> logger,
    ModHelper modHelper,
    GlobalTable globalTable) : IOnLoad
{
    public Task OnLoadAsync(CancellationToken cancellationToken)
    {
        var config = modHelper.GetJsonDataFromModFile<ModConfig>("config", "config.json");
        var multiplier = config.WeightLimitsMultiplier;
        var stamina = globalTable.Configuration.Stamina;

        stamina.BaseOverweightLimits = MultiplyXAndY(stamina.BaseOverweightLimits, multiplier);
        stamina.SprintOverweightLimits = MultiplyXAndY(
            stamina.SprintOverweightLimits,
            multiplier
        );
        stamina.WalkOverweightLimits = MultiplyXAndY(stamina.WalkOverweightLimits, multiplier);
        stamina.WalkSpeedOverweightLimits = MultiplyXAndY(
            stamina.WalkSpeedOverweightLimits,
            multiplier
        );

        var inertia = globalTable.Configuration.Inertia;
        inertia.InertiaLimits = inertia.InertiaLimits with
        {
            Y = inertia.InertiaLimits.Y * multiplier,
        };

        logger.LogWithColor(
            $"SPT Multiply Weight Limits loaded. Weight limit multiplier is set to {multiplier}.",
            Color.Green
        );

        return Task.CompletedTask;
    }

    private static SPTarkov.Server.Core.Models.Eft.Common.Vector3 MultiplyXAndY(
        SPTarkov.Server.Core.Models.Eft.Common.Vector3 value,
        float multiplier
    )
    {
        return value with
        {
            X = value.X * multiplier,
            Y = value.Y * multiplier,
        };
    }
}

public sealed class ModConfig
{
    public float WeightLimitsMultiplier { get; set; }
}
