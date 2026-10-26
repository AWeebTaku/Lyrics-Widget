#pragma once
#include <QColor>
#include <QImage>
#include <QList>
#include <algorithm>

// Up to four distinct, readable colours of a cover. A 24x24 thumbnail is sorted into 12 hue buckets
// weighted by saturation and brightness; the strongest bucket is the main colour, then the strongest
// buckets at least 60 degrees of hue away from the ones already picked. Each colour is brightened to a
// tone that reads on a dark background. Black-and-white or washed-out covers have no hues, so their exact shades
// of grey (black and white included) are used instead.
namespace Palette {

inline QList<QColor> of(const QImage &src, int maxColors = 4)
{
    const QImage img = src.scaled(24, 24, Qt::IgnoreAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_RGB32);
    double w[12] = {}, r[12] = {}, g[12] = {}, b[12] = {};
    double gn[4] = {}, gr[4] = {}, gg[4] = {}, gb[4] = {}; // greys by brightness: dark .. white
    for (int y = 0; y < img.height(); ++y)
        for (int x = 0; x < img.width(); ++x) {
            const QColor c = img.pixelColor(x, y);
            const double wt = c.hsvSaturationF() * c.valueF();
            if (wt >= 0.05 && c.hsvHue() >= 0) {
                const int k = c.hsvHue() / 30 % 12;
                w[k] += wt; r[k] += wt * c.redF(); g[k] += wt * c.greenF(); b[k] += wt * c.blueF();
            }
            if (c.hsvSaturationF() < 0.2) { // grey-ish pixel
                const int k = std::min(3, int(c.valueF() * 4));
                gn[k] += 1; gr[k] += c.redF(); gg[k] += c.greenF(); gb[k] += c.blueF();
            }
        }

    QList<QColor> out;
    int order[12];
    for (int k = 0; k < 12; ++k)
        order[k] = k;
    std::sort(order, order + 12, [&](int a, int c) { return w[a] > w[c]; });
    if (w[order[0]] >= 1.5) {
        QList<int> picked;
        for (int i = 0; i < 12 && out.size() < maxColors; ++i) {
            const int k = order[i];
            if (w[k] < 0.25 * w[order[0]] || w[k] < 0.8)
                break; // too little of this hue to matter
            bool apart = true;
            for (int p : std::as_const(picked)) {
                const int d = std::abs(k - p);
                apart &= std::min(d, 12 - d) >= 2;
            }
            if (!apart)
                continue;
            picked << k;
            float h, s, l;
            QColor::fromRgbF(r[k] / w[k], g[k] / w[k], b[k] / w[k]).getHslF(&h, &s, &l);
            out << QColor::fromHslF(h, std::max(s, 0.45f), std::clamp(l, 0.62f, 0.8f));
        }
    }

    // Greys, black and white: the cover's own shades, exactly as they are (never two alike). This is what a
    // black, white or grey cover gets, and it fills up a cover that has only one real colour.
    if (out.size() < 2) {
        int gorder[4] = {0, 1, 2, 3};
        std::sort(gorder, gorder + 4, [&](int a, int c) { return gn[a] > gn[c]; });
        const double total = gn[0] + gn[1] + gn[2] + gn[3];
        for (int i = 0; i < 4 && out.size() < maxColors; ++i) {
            const int k = gorder[i];
            if (gn[k] < 0.06 * std::max(total, 1.0) || gn[k] < 8)
                continue;
            const QColor c = QColor::fromRgbF(gr[k] / gn[k], gg[k] / gn[k], gb[k] / gn[k]);
            bool alike = false;
            for (const QColor &o : std::as_const(out))
                alike |= std::abs(o.lightnessF() - c.lightnessF()) < 0.08;
            if (!alike)
                out << c;
        }
    }
    return out;
}

} // namespace Palette
