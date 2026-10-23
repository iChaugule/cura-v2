/**
 * A small slippy map.
 *
 * Renders OpenStreetMap-derived raster tiles and positions caregiver pins at
 * their true coordinates relative to the person needing care. Plain <Image>
 * tiles keep this working on iOS, Android and web with no native map module.
 */
import React, { useMemo, useState } from 'react';
import { View, Text, Image, Pressable, StyleSheet, ActivityIndicator } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { Colors, Radius, Shadow } from '../design/tokens';
import type { GeoPoint } from '../models/types';
import {
  TILE_SIZE, TILE_ATTRIBUTION, latToTileY, lngToTileX, pixelOffset, tileUrl,
  zoomForRadius, haversineKm,
} from '../lib/geo';

export interface MapPin {
  id: string;
  point: GeoPoint;
  label: string;
  initials: string;
}

interface Props {
  center: GeoPoint;
  centerLabel: string;
  pins: MapPin[];
  selectedId?: string | null;
  onSelectPin?: (id: string) => void;
  height?: number;
}

export function CareMap({
  center, centerLabel, pins, selectedId, onSelectPin, height = 240,
}: Props) {
  const [width, setWidth] = useState(0);
  const [failedTiles, setFailedTiles] = useState<Record<string, true>>({});

  const zoom = useMemo(() => {
    if (!width) return 13;
    // Fit most of the results rather than the single furthest outlier — one
    // caregiver 8km away should not zoom the whole map out to a smudge.
    const distances = pins
      .map(p => haversineKm(center, p.point))
      .sort((a, b) => a - b);
    const cutoff = distances.length
      ? distances[Math.floor(distances.length * 0.7)]
      : 0.8;
    return zoomForRadius(Math.max(0.8, cutoff) * 1.3, width, center.lat);
  }, [width, pins, center]);

  const tiles = useMemo(() => {
    if (!width) return [];
    const centerWorldX = lngToTileX(center.lng, zoom) * TILE_SIZE;
    const centerWorldY = latToTileY(center.lat, zoom) * TILE_SIZE;
    const originX = centerWorldX - width / 2;
    const originY = centerWorldY - height / 2;

    const firstX = Math.floor(originX / TILE_SIZE);
    const lastX = Math.floor((originX + width) / TILE_SIZE);
    const firstY = Math.floor(originY / TILE_SIZE);
    const lastY = Math.floor((originY + height) / TILE_SIZE);

    const out: { key: string; uri: string; left: number; top: number }[] = [];
    const maxTile = 2 ** zoom - 1;
    for (let x = firstX; x <= lastX; x++) {
      for (let y = firstY; y <= lastY; y++) {
        if (y < 0 || y > maxTile) continue;
        out.push({
          key: `${zoom}/${x}/${y}`,
          uri: tileUrl(x, y, zoom),
          left: x * TILE_SIZE - originX,
          top: y * TILE_SIZE - originY,
        });
      }
    }
    return out;
  }, [width, height, zoom, center]);

  const placed = useMemo(() => {
    const margin = 20;
    return pins.map(p => {
      const off = pixelOffset(center, p.point, zoom);
      const x = width / 2 + off.x;
      const y = height / 2 + off.y;
      const offscreen =
        x < margin || x > width - margin || y < margin || y > height - margin;
      return {
        ...p,
        // Caregivers beyond the viewport are pinned to the edge in their true
        // direction rather than dropped, so the map never contradicts the list.
        x: Math.max(margin, Math.min(width - margin, x)),
        y: Math.max(margin, Math.min(height - margin, y)),
        offscreen,
      };
    });
  }, [pins, center, zoom, width, height]);

  return (
    <View
      style={[styles.wrap, { height }]}
      onLayout={e => setWidth(e.nativeEvent.layout.width)}
      accessibilityLabel={`Map showing ${pins.length} caregivers near ${centerLabel}`}
    >
      {/* Tiles */}
      <View style={StyleSheet.absoluteFill}>
        {width === 0 ? (
          <View style={styles.loading}>
            <ActivityIndicator color={Colors.brown} />
          </View>
        ) : (
          tiles.map(t =>
            failedTiles[t.key] ? null : (
              <Image
                key={t.key}
                source={{ uri: t.uri }}
                onError={() => setFailedTiles(f => ({ ...f, [t.key]: true }))}
                style={[styles.tile, { left: t.left, top: t.top }]}
              />
            ),
          )
        )}
      </View>

      {/* Warm wash so the map belongs to the rest of the app */}
      <View pointerEvents="none" style={styles.tint} />

      {width > 0 && (
        <>
          {/* Caregiver pins */}
          {placed.map(p => {
            const active = p.id === selectedId;
            return (
              <Pressable
                key={p.id}
                onPress={() => onSelectPin?.(p.id)}
                accessibilityRole="button"
                accessibilityLabel={p.offscreen ? `${p.label}, beyond the map edge` : p.label}
                accessibilityState={{ selected: active }}
                style={[
                  styles.pin,
                  p.offscreen && !active && styles.pinFar,
                  active && styles.pinActive,
                  { left: p.x - 17, top: p.y - 17 },
                ]}
              >
                <Text
                  style={[
                    styles.pinText,
                    p.offscreen && !active && { color: Colors.textSecondary },
                    active && { color: Colors.textOnBrown },
                  ]}
                >
                  {p.initials}
                </Text>
              </Pressable>
            );
          })}

          {/* Home marker, drawn last so it sits on top */}
          <View
            pointerEvents="none"
            style={[styles.home, { left: width / 2 - 15, top: height / 2 - 15 }]}
          >
            <Ionicons name="home" size={15} color={Colors.textOnBrown} />
          </View>
        </>
      )}

      <View pointerEvents="none" style={styles.attribution}>
        <Text style={styles.attributionText}>{TILE_ATTRIBUTION}</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    borderRadius: Radius.lg,
    overflow: 'hidden',
    backgroundColor: Colors.surfaceTinted,
    borderWidth: 1,
    borderColor: Colors.separator,
  },
  tile: { position: 'absolute', width: TILE_SIZE, height: TILE_SIZE },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  // Spelled out rather than spreading StyleSheet.absoluteFill — RN 0.86 dropped
  // `absoluteFillObject`, and this is version-proof.
  tint: {
    position: 'absolute', top: 0, left: 0, right: 0, bottom: 0,
    backgroundColor: 'rgba(242,235,225,0.14)',
  },

  pin: {
    position: 'absolute',
    width: 34, height: 34, borderRadius: 17,
    backgroundColor: Colors.surfaceRaised,
    borderWidth: 2, borderColor: Colors.brown,
    alignItems: 'center', justifyContent: 'center',
    ...Shadow.card,
  },
  pinActive: { backgroundColor: Colors.brown, transform: [{ scale: 1.15 }] },
  /** Clamped to the edge — dimmed so it reads as "further than this view". */
  pinFar: { borderColor: Colors.border, opacity: 0.75, transform: [{ scale: 0.88 }] },
  pinText: { fontSize: 12, fontWeight: '800', color: Colors.brown },

  home: {
    position: 'absolute',
    width: 30, height: 30, borderRadius: 15,
    backgroundColor: Colors.textStrong,
    borderWidth: 3, borderColor: Colors.cream,
    alignItems: 'center', justifyContent: 'center',
    ...Shadow.lifted,
  },

  attribution: {
    position: 'absolute', right: 0, bottom: 0,
    backgroundColor: 'rgba(251,247,241,0.82)',
    paddingHorizontal: 6, paddingVertical: 2,
    borderTopLeftRadius: Radius.sm,
  },
  attributionText: { fontSize: 9, color: Colors.textSecondary },
});
