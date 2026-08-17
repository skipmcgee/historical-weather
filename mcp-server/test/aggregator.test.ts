import { describe, expect, it } from "vitest";
import { aggregateDailyArchive, hasAnyData } from "../src/aggregator.js";
import type { Location } from "../src/types.js";

const location: Location = { name: "Test", latitude: 30.27, longitude: -97.74, manual: true };
const start = "2020-01-01";
const end = "2020-01-03";

describe("aggregateDailyArchive", () => {
  it("computes medians and sums across all days", () => {
    const summary = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02", "2020-01-03"],
        temperature_2m_max: [10.0, 12.0, 14.0],
        temperature_2m_min: [0.0, 2.0, 4.0],
        precipitation_sum: [1.0, 0.0, 3.0],
        rain_sum: [1.0, 0.0, 3.0],
        snowfall_sum: [0.0, 0.0, 0.0],
        wind_speed_10m_max: [10.0, 20.0, 30.0],
        wind_gusts_10m_max: [15.0, 25.0, 35.0],
        wind_direction_10m_dominant: [80.0, 90.0, 100.0],
        relative_humidity_2m_mean: [70.0, 80.0, 90.0],
        shortwave_radiation_sum: [5.0, 6.0, 7.0],
        sunshine_duration: [3600.0, 7200.0, 10800.0],
      },
    });

    expect(summary.dayCount).toBe(3);
    expect(summary.method).toBe("median");
    expect(summary.highC).toBeCloseTo(12.0, 9);
    expect(summary.lowC).toBeCloseTo(2.0, 9);
    expect(summary.meanC).toBeCloseTo(7.0, 9);
    expect(summary.totalPrecipitationMm).toBeCloseTo(4.0, 9);
    // Sorted [0, 1, 3] -> median is the middle value, 1.0 (not the mean, 4/3).
    expect(summary.precipitationPerDayMm).toBeCloseTo(1.0, 9);
    expect(summary.totalRainMm).toBeCloseTo(4.0, 9);
    expect(summary.totalSnowfallCm).toBeCloseTo(0.0, 9);
    expect(summary.windSpeedMaxKmh).toBeCloseTo(20.0, 9);
    expect(summary.windGustsMaxKmh).toBeCloseTo(25.0, 9);
    // [80, 90, 100] is symmetric around 90 -> circular mean is exactly 90.
    expect(summary.windDirectionDeg).toBeCloseTo(90.0, 6);
    expect(summary.relativeHumidityPercent).toBeCloseTo(80.0, 9);
    expect(summary.shortwaveRadiationMjm2).toBeCloseTo(6.0, 9);
    // sunshine_duration is in seconds; median of 1h/2h/3h -> 2 hours.
    expect(summary.sunshineHours).toBeCloseTo(2.0, 9);
    expect(hasAnyData(summary)).toBe(true);
  });

  it("uses the arithmetic mean instead of the median for AggregationMethod 'average'", () => {
    const daily = {
      time: ["2020-01-01", "2020-01-02", "2020-01-03"],
      // Sorted [0, 1, 20]: median is 1.0, but the mean is 7.0 -- a single
      // outlier day should only move the average, not the median.
      precipitation_sum: [1.0, 0.0, 20.0],
      temperature_2m_max: [10.0, 12.0, 100.0],
    };

    const median = aggregateDailyArchive({ location, startDate: start, endDate: end, method: "median", daily });
    const average = aggregateDailyArchive({ location, startDate: start, endDate: end, method: "average", daily });

    expect(median.precipitationPerDayMm).toBeCloseTo(1.0, 9);
    expect(median.highC).toBeCloseTo(12.0, 9);

    expect(average.precipitationPerDayMm).toBeCloseTo(7.0, 9);
    expect(average.highC).toBeCloseTo((10.0 + 12.0 + 100.0) / 3, 9);

    // Totals are sums regardless of method -- unaffected by the choice.
    expect(median.totalPrecipitationMm).toBeCloseTo(21.0, 9);
    expect(average.totalPrecipitationMm).toBeCloseTo(21.0, 9);
  });

  it("wind direction is always a circular mean, regardless of AggregationMethod", () => {
    const daily = { time: ["2020-01-01", "2020-01-02"], wind_direction_10m_dominant: [350.0, 10.0] };

    const median = aggregateDailyArchive({ location, startDate: start, endDate: end, method: "median", daily });
    const average = aggregateDailyArchive({ location, startDate: start, endDate: end, method: "average", daily });

    expect(median.windDirectionDeg).toBeCloseTo(0.0, 6);
    expect(average.windDirectionDeg).toBeCloseTo(0.0, 6);
  });

  it("computes atmosphere, evapotranspiration, and soil metrics", () => {
    const summary = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02", "2020-01-03"],
        dew_point_2m_mean: [10.0, 12.0, 14.0],
        cloud_cover_mean: [20.0, 50.0, 80.0],
        surface_pressure_mean: [1000.0, 1010.0, 1020.0],
        et0_fao_evapotranspiration: [1.0, 2.0, 3.0],
        soil_moisture_0_to_7cm_mean: [0.3, 0.32, 0.34],
        soil_moisture_7_to_28cm_mean: [0.35, 0.36, 0.37],
        soil_moisture_28_to_100cm_mean: [0.4, 0.4, 0.41],
        soil_temperature_0_to_7cm_mean: [15.0, 16.0, 17.0],
        soil_temperature_7_to_28cm_mean: [14.0, 14.5, 15.0],
        soil_temperature_28_to_100cm_mean: [13.0, 13.0, 13.5],
      },
    });

    expect(summary.dewPointC).toBeCloseTo(12.0, 9);
    expect(summary.cloudCoverPercent).toBeCloseTo(50.0, 9);
    expect(summary.surfacePressureHpa).toBeCloseTo(1010.0, 9);
    expect(summary.totalEt0Mm).toBeCloseTo(6.0, 9);
    expect(summary.et0MmPerDay).toBeCloseTo(2.0, 9);
    expect(summary.soilMoisture0To7cm).toBeCloseTo(0.32, 9);
    expect(summary.soilMoisture7To28cm).toBeCloseTo(0.36, 9);
    expect(summary.soilMoisture28To100cm).toBeCloseTo(0.4, 9);
    expect(summary.soilTemp0To7cmC).toBeCloseTo(16.0, 9);
    expect(summary.soilTemp7To28cmC).toBeCloseTo(14.5, 9);
    expect(summary.soilTemp28To100cmC).toBeCloseTo(13.0, 9);
    expect(hasAnyData(summary)).toBe(true);
  });

  it("wind direction is averaged circularly, not numerically", () => {
    const wrapped = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02"],
        // A plain numeric mean/median of [350, 10] gives 180 (due south) --
        // the correct circular average, wrapping across 0/360, is ~0 (north).
        wind_direction_10m_dominant: [350.0, 10.0],
      },
    });
    expect(wrapped.windDirectionDeg).toBeCloseTo(0.0, 6);

    const opposite = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02"],
        // Directly opposite directions cancel out -> no representative
        // single direction, so this should be null rather than a guess.
        wind_direction_10m_dominant: [0.0, 180.0],
      },
    });
    expect(opposite.windDirectionDeg).toBeNull();
  });

  it("median of an even number of days averages the two middle values", () => {
    const summary = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: "2020-01-04",
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02", "2020-01-03", "2020-01-04"],
        temperature_2m_max: [10.0, 20.0, 30.0, 40.0],
      },
    });

    // Sorted [10, 20, 30, 40] -> median is the average of the two middle
    // values, (20 + 30) / 2 = 25, not a single sample.
    expect(summary.highC).toBeCloseTo(25.0, 9);
  });

  it("skips null values instead of treating them as zero", () => {
    const summary = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: {
        time: ["2020-01-01", "2020-01-02", "2020-01-03"],
        temperature_2m_max: [10.0, null, 14.0],
        temperature_2m_min: [0.0, null, 4.0],
        precipitation_sum: [null, null, null],
      },
    });

    expect(summary.dayCount).toBe(3);
    expect(summary.highC).toBeCloseTo(12.0, 9);
    expect(summary.meanC).toBeCloseTo(7.0, 9);
    expect(summary.totalPrecipitationMm).toBeNull();
    expect(summary.precipitationPerDayMm).toBeNull();
    expect(hasAnyData(summary)).toBe(true);
  });

  it('handles entirely empty daily data as "no data" rather than crashing', () => {
    const summary = aggregateDailyArchive({
      location,
      startDate: start,
      endDate: end,
      method: "median",
      daily: { time: [] },
    });

    expect(summary.dayCount).toBe(0);
    expect(summary.highC).toBeNull();
    expect(summary.meanC).toBeNull();
    expect(hasAnyData(summary)).toBe(false);
  });
});
