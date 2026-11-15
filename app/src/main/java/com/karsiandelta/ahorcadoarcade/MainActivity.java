package com.karsiandelta.ahorcadoarcade;

import android.app.Activity;
import android.os.Bundle;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;

import androidx.annotation.NonNull;
import androidx.core.graphics.Insets;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowInsetsCompat;

import com.google.android.gms.ads.AdError;
import com.google.android.gms.ads.AdRequest;
import com.google.android.gms.ads.FullScreenContentCallback;
import com.google.android.gms.ads.LoadAdError;
import com.google.android.gms.ads.MobileAds;
import com.google.android.gms.ads.rewarded.RewardedAd;
import com.google.android.gms.ads.rewarded.RewardedAdLoadCallback;
import com.google.android.ump.ConsentInformation;
import com.google.android.ump.ConsentRequestParameters;
import com.google.android.ump.UserMessagingPlatform;

import java.util.concurrent.atomic.AtomicBoolean;

/** Pantalla única: el juego es una página web local dentro de un WebView. Los anuncios se piden desde la página con window.AndroidAds. */
public class MainActivity extends Activity {
    private static final int BG = 0xff170e2e;

    private WebView web;
    private ConsentInformation consent;
    private volatile RewardedAd ad;
    private boolean loading;
    private final AtomicBoolean adsStarted = new AtomicBoolean(false);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BG);

        web = new WebView(this);
        web.setBackgroundColor(BG);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setSupportZoom(false);
        s.setTextZoom(100);
        web.addJavascriptInterface(new Bridge(), "AndroidAds");
        root.addView(web, new FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        // Desde Android 15 la app se dibuja de borde a borde: dejamos hueco para las barras del sistema, el recorte y el teclado.
        ViewCompat.setOnApplyWindowInsetsListener(root, (v, insets) -> {
            Insets i = insets.getInsets(WindowInsetsCompat.Type.systemBars()
                    | WindowInsetsCompat.Type.displayCutout()
                    | WindowInsetsCompat.Type.ime());
            v.setPadding(i.left, i.top, i.right, i.bottom);
            return WindowInsetsCompat.CONSUMED;
        });

        web.loadUrl("file:///android_asset/index.html");
        setupConsentAndAds();
    }

    /** Pide el consentimiento (RGPD) si hace falta y solo después arranca los anuncios. */
    private void setupConsentAndAds() {
        consent = UserMessagingPlatform.getConsentInformation(this);
        consent.requestConsentInfoUpdate(this, new ConsentRequestParameters.Builder().build(),
                () -> UserMessagingPlatform.loadAndShowConsentFormIfRequired(this, formError -> {
                    if (consent.canRequestAds()) startAds();
                }),
                requestError -> {
                    if (consent.canRequestAds()) startAds();
                });
        if (consent.canRequestAds()) startAds();
    }

    private void startAds() {
        if (adsStarted.getAndSet(true)) return;
        new Thread(() -> MobileAds.initialize(this, status -> runOnUiThread(this::loadAd))).start();
    }

    private void loadAd() {
        if (loading || ad != null || !adsStarted.get()) return;
        loading = true;
        RewardedAd.load(this, BuildConfig.REWARDED_ID, new AdRequest.Builder().build(), new RewardedAdLoadCallback() {
            @Override
            public void onAdLoaded(@NonNull RewardedAd loaded) {
                ad = loaded;
                loading = false;
                js("window.adState&&window.adState(true)");
            }

            @Override
            public void onAdFailedToLoad(@NonNull LoadAdError error) {
                ad = null;
                loading = false;
                js("window.adState&&window.adState(false)");
            }
        });
    }

    private void showAd() {
        final RewardedAd current = ad;
        if (current == null) {
            loadAd();
            js("window.adResult&&window.adResult(false)");
            return;
        }
        ad = null;
        final boolean[] earned = {false};
        current.setFullScreenContentCallback(new FullScreenContentCallback() {
            @Override
            public void onAdDismissedFullScreenContent() {
                js("window.adResult&&window.adResult(" + earned[0] + ")");
                loadAd();
            }

            @Override
            public void onAdFailedToShowFullScreenContent(@NonNull AdError error) {
                js("window.adResult&&window.adResult(false)");
                loadAd();
            }
        });
        current.show(this, reward -> earned[0] = true);
    }

    private void js(String code) {
        runOnUiThread(() -> {
            if (web != null) web.evaluateJavascript(code, null);
        });
    }

    /** Lo que la página puede llamar: AndroidAds.ready(), .show(), .needsPrivacy(), .privacy(). */
    private class Bridge {
        @JavascriptInterface
        public boolean ready() {
            return ad != null;
        }

        @JavascriptInterface
        public void show() {
            runOnUiThread(MainActivity.this::showAd);
        }

        @JavascriptInterface
        public boolean needsPrivacy() {
            return consent != null && consent.getPrivacyOptionsRequirementStatus()
                    == ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED;
        }

        @JavascriptInterface
        public void privacy() {
            runOnUiThread(() -> UserMessagingPlatform.showPrivacyOptionsForm(MainActivity.this, formError -> { }));
        }
    }

    @Override
    protected void onPause() {
        if (web != null) web.onPause();
        super.onPause();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) web.onResume();
    }

    @Override
    protected void onDestroy() {
        if (web != null) {
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
