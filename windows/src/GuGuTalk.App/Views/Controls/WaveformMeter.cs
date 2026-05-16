using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace GuGuTalk.App.Views.Controls;

public sealed class WaveformMeter : Control
{
    private const int BarCount = 12;

    public static readonly DependencyProperty LevelProperty =
        DependencyProperty.Register(nameof(Level), typeof(float), typeof(WaveformMeter),
            new FrameworkPropertyMetadata(0f, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty BarBrushProperty =
        DependencyProperty.Register(nameof(BarBrush), typeof(Brush), typeof(WaveformMeter),
            new FrameworkPropertyMetadata(Brushes.Teal, FrameworkPropertyMetadataOptions.AffectsRender));

    public float Level
    {
        get => (float)GetValue(LevelProperty);
        set => SetValue(LevelProperty, value);
    }

    public Brush BarBrush
    {
        get => (Brush)GetValue(BarBrushProperty);
        set => SetValue(BarBrushProperty, value);
    }

    private readonly float[] _barHeights = new float[BarCount];
    private readonly Random _random = new();

    static WaveformMeter()
    {
        DefaultStyleKeyProperty.OverrideMetadata(
            typeof(WaveformMeter),
            new FrameworkPropertyMetadata(typeof(WaveformMeter)));
    }

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);

        double w = ActualWidth;
        double h = ActualHeight;
        if (w <= 0 || h <= 0) return;

        double gap = 2;
        double barWidth = (w - gap * (BarCount - 1)) / BarCount;
        double minBarHeight = h * 0.15;

        // Update bar heights with simple animation (decay + new spike on level)
        for (int i = 0; i < BarCount; i++)
        {
            float target = Level * (0.6f + (float)_random.NextDouble() * 0.4f);
            _barHeights[i] = Math.Max(_barHeights[i] * 0.85f, target);
        }

        for (int i = 0; i < BarCount; i++)
        {
            double barHeight = Math.Max(minBarHeight, _barHeights[i] * h);
            double x = i * (barWidth + gap);
            double y = (h - barHeight) / 2;

            var rect = new Rect(x, y, barWidth, barHeight);
            dc.DrawRoundedRectangle(BarBrush, null, rect, barWidth / 2, barWidth / 2);
        }
    }
}
