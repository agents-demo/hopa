using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace Hopa.Windows.Ui.Chat;

/// <summary>
/// The plush HOPA avatar. The empty state uses the idle float, breathe and blink;
/// transcript avatars set <see cref="IsStatic"/> so dozens of rows cost nothing.
/// </summary>
public partial class HopaAvatar : UserControl
{
    public static readonly DependencyProperty IsStaticProperty = DependencyProperty.Register(
        nameof(IsStatic),
        typeof(bool),
        typeof(HopaAvatar),
        new PropertyMetadata(false, OnIsStaticChanged));

    private static readonly TimeSpan IdleDuration = TimeSpan.FromMilliseconds(2400);
    private static readonly TimeSpan BlinkInterval = TimeSpan.FromMilliseconds(4200);
    private static readonly TimeSpan BlinkHold = TimeSpan.FromMilliseconds(150);

    private readonly DispatcherTimer blinkOn = new() { Interval = BlinkInterval };
    private readonly DispatcherTimer blinkOff = new() { Interval = BlinkHold };

    public HopaAvatar()
    {
        InitializeComponent();
        Loaded += (_, _) =>
        {
            ApplyClip();
            StartMotion();
        };
        Unloaded += (_, _) => StopMotion();
        IsVisibleChanged += (_, _) =>
        {
            if (IsVisible)
            {
                StartMotion();
            }
            else
            {
                StopMotion();
            }
        };
        SizeChanged += (_, _) => ApplyClip();
        blinkOn.Tick += (_, _) =>
        {
            Blink.Opacity = 1;
            blinkOff.Start();
        };
        blinkOff.Tick += (_, _) =>
        {
            Blink.Opacity = 0;
            blinkOff.Stop();
        };
    }

    public bool IsStatic
    {
        get => (bool)GetValue(IsStaticProperty);
        set => SetValue(IsStaticProperty, value);
    }

    private static void OnIsStaticChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not HopaAvatar mark)
        {
            return;
        }

        mark.StopMotion();
        mark.StartMotion();
    }

    private void ApplyClip()
    {
        var width = Math.Max(ActualWidth, 0);
        var height = Math.Max(ActualHeight, 0);
        Surface.Clip = width > 0 && height > 0
            ? new RectangleGeometry(new Rect(0, 0, width, height), width * 0.20, height * 0.20)
            : null;
    }

    private void StartMotion()
    {
        if (IsStatic || !IsLoaded || !IsVisible || !SystemParameters.ClientAreaAnimation)
        {
            return;
        }

        Blink.Source ??= new BitmapImage(
            new Uri("pack://application:,,,/Hopa.Windows;component/Assets/mascot-blink.png", UriKind.Absolute)
        );
        Float.BeginAnimation(TranslateTransform.YProperty, FloatAnimation());
        Breathe.BeginAnimation(ScaleTransform.ScaleYProperty, ScaleAnimation(1.025));
        Breathe.BeginAnimation(ScaleTransform.ScaleXProperty, ScaleAnimation(0.99));
        blinkOn.Start();
    }

    private void StopMotion()
    {
        blinkOn.Stop();
        blinkOff.Stop();
        Float.BeginAnimation(TranslateTransform.YProperty, null);
        Breathe.BeginAnimation(ScaleTransform.ScaleYProperty, null);
        Breathe.BeginAnimation(ScaleTransform.ScaleXProperty, null);
        Float.Y = 0;
        Breathe.ScaleX = 1;
        Breathe.ScaleY = 1;
        Blink.Opacity = 0;
        if (IsStatic)
        {
            Blink.Source = null;
        }
    }

    private static DoubleAnimation FloatAnimation() =>
        new(0, -2.2, IdleDuration)
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut },
        };

    private static DoubleAnimation ScaleAnimation(double to) =>
        new(1, to, IdleDuration)
        {
            AutoReverse = true,
            RepeatBehavior = RepeatBehavior.Forever,
            EasingFunction = new SineEase { EasingMode = EasingMode.EaseInOut },
        };
}
