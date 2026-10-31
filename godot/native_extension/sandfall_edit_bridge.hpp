#pragma once

#include "cyber_native_cell_world.hpp"
#include "cybersand/demo_snapshot.hpp"
#include <bit>
#include <cstring>
#include <godot_cpp/core/class_db.hpp>

namespace godot {

// Exclusive Godot owner, between ticks. Owned logical values, not a second
// solver or a physics rewind API. No mask, feedback, tick or contact-cache reset.
class SandfallEditBridge final : public RefCounted {
    GDCLASS(SandfallEditBridge, RefCounted)
    static constexpr int kWidth = 1024;
    static constexpr int kCells = kWidth * kWidth;
    static constexpr int kTuple = 5;
    static constexpr int kMaxPatch = kCells;

    static Dictionary result(bool ok, const String& error = String(), bool partial = false) {
        Dictionary out;
        out["ok"] = ok;
        out["error"] = error;
        out["partial"] = partial;
        return out;
    }
    static bool supported(const CyberNativeCellWorld& adapter) {
        return adapter.world_ && !adapter.world_->has_failed()
            && adapter.world_->config().water_experiment_policy == cybersand::WaterExperimentPolicy{}
            && adapter.world_->liquid_solver_policy() == cybersand::LiquidSolverPolicy{};
    }
    static bool valid_rectangle(const Rect2i& r) {
        return r.position.x >= 0 && r.position.y >= 0 && r.size.x > 0 && r.size.y > 0
            && r.size.x <= kWidth && r.size.y <= kWidth
            && r.position.x <= kWidth - r.size.x && r.position.y <= kWidth - r.size.y;
    }
    static bool valid_tuple(const uint8_t* p) {
        return cybersand::valid_material(p[0])
            && (p[0] != static_cast<uint8_t>(cybersand::Material::Water)
                || (p[1] > 0 && p[2] <= cybersand::WaterExperimentPolicy::kMaximumCoherenceTicks));
    }
    static void read_tuple(const cybersand::World& world, int index, uint8_t* p) {
        const int x = index % kWidth, y = index / kWidth;
        p[0] = static_cast<uint8_t>(world.stored_material(x, y));
        p[1] = static_cast<uint8_t>(world.stored_state_a(x, y));
        p[2] = world.stored_state_b(x, y);
        const auto t = std::bit_cast<uint16_t>(world.stored_temperature(x, y));
        p[3] = static_cast<uint8_t>(t);
        p[4] = static_cast<uint8_t>(t >> 8U);
    }

public:
    Array catalogue() const {
        Array rows;
        static constexpr const char* families[] = {"empty", "solid", "powder", "liquid", "gas", "agent"};
        for (size_t id = 0; id < cybersand::kMaterialDefinitions.size(); ++id) {
            const auto& d = cybersand::kMaterialDefinitions[id];
            if (!d.valid) continue;
            Dictionary row;
            row["id"] = static_cast<int64_t>(id);
            row["name"] = String(d.name.data());
            row["family"] = String(families[static_cast<size_t>(d.state)]);
            row["state_a"] = static_cast<int64_t>(d.initial_state_a);
            row["state_b"] = static_cast<int64_t>(d.initial_state_b);
            row["temperature"] = 200; // Native integer units; no invented Celsius conversion.
            row["rule_available"] = d.current_rule_available;
            row["rgba"] = Color(d.rgba[0] / 255.0, d.rgba[1] / 255.0, d.rgba[2] / 255.0, d.rgba[3] / 255.0);
            rows.push_back(row);
        }
        return rows;
    }

    Dictionary validate_cells(const PackedByteArray& cells) const {
        if (cells.size() != kCells * kTuple) return result(false, "wrong_cell_payload_length");
        const uint8_t* p = cells.ptr();
        for (int i = 0; i < kCells; ++i)
            if (!valid_tuple(p + i * kTuple)) return result(false, "invalid_cell_tuple");
        return result(true);
    }

    Dictionary plan_patch(const PackedByteArray& current, const PackedInt32Array& indices,
                          const PackedByteArray& desired) const {
        const int64_t n = indices.size();
        if (current.size() != kCells * kTuple || n < 1 || n > kMaxPatch || desired.size() != n * kTuple)
            return result(false, "invalid_patch_size");
        const auto* ip = indices.ptr();
        const auto* cp = current.ptr();
        const auto* dp = desired.ptr();
        for (int64_t i = 0; i < n; ++i) {
            if (ip[i] < 0 || ip[i] >= kCells || (i > 0 && ip[i] <= ip[i - 1]))
                return result(false, "indices_must_be_unique_sorted_in_bounds");
            if (!valid_tuple(dp + i * kTuple)) return result(false, "invalid_cell_tuple");
        }
        PackedInt32Array changed;
        PackedByteArray before, after, candidate = current.duplicate();
        changed.resize(n); before.resize(n * kTuple); after.resize(n * kTuple);
        auto* ci = changed.ptrw(); auto* bp = before.ptrw(); auto* ap = after.ptrw();
        auto* next = candidate.ptrw();
        int64_t count = 0;
        for (int64_t i = 0; i < n; ++i) {
            const auto* old = cp + ip[i] * kTuple;
            const auto* value = dp + i * kTuple;
            if (std::memcmp(old, value, kTuple) == 0) continue;
            ci[count] = ip[i];
            std::memcpy(bp + count * kTuple, old, kTuple);
            std::memcpy(ap + count * kTuple, value, kTuple);
            std::memcpy(next + ip[i] * kTuple, value, kTuple);
            ++count;
        }
        if (count == 0) return result(false, "no_effect");
        changed.resize(count); before.resize(count * kTuple); after.resize(count * kTuple);
        Dictionary out = result(true);
        out["indices"] = changed; out["before"] = before; out["after"] = after;
        out["candidate"] = candidate;
        return out;
    }

    PackedByteArray repeated_tuple(const PackedByteArray& value, int64_t count) const {
        PackedByteArray out;
        if (value.size() != kTuple || count < 0 || count > kCells || !valid_tuple(value.ptr())) return out;
        out.resize(count * kTuple);
        auto* p = out.ptrw();
        for (int64_t i = 0; i < count; ++i) std::memcpy(p + i * kTuple, value.ptr(), kTuple);
        return out;
    }

    PackedByteArray extract_rectangle(const PackedByteArray& cells, const Rect2i& rectangle) const {
        PackedByteArray out;
        if (cells.size() != kCells * kTuple || !valid_rectangle(rectangle)) return out;
        out.resize(static_cast<int64_t>(rectangle.size.x) * rectangle.size.y * kTuple);
        for (int y = 0; y < rectangle.size.y; ++y)
            std::memcpy(out.ptrw() + y * rectangle.size.x * kTuple,
                cells.ptr() + ((rectangle.position.y + y) * kWidth + rectangle.position.x) * kTuple,
                rectangle.size.x * kTuple);
        return out;
    }

    Dictionary selection_patch(const PackedByteArray& cells, const Rect2i& source,
                               const Rect2i& destination, const PackedByteArray& clipboard, bool move) const {
        if (cells.size() != kCells * kTuple || !valid_rectangle(destination)
            || clipboard.size() != static_cast<int64_t>(destination.size.x) * destination.size.y * kTuple
            || (move && (!valid_rectangle(source) || source.size != destination.size)))
            return result(false, "selection_out_of_bounds_or_malformed");
        for (int64_t i = 0; i < clipboard.size(); i += kTuple)
            if (!valid_tuple(clipboard.ptr() + i)) return result(false, "invalid_clipboard_tuple");
        PackedByteArray next = cells.duplicate();
        auto* p = next.ptrw();
        static constexpr uint8_t empty[kTuple] = {0, 0, 0, 200, 0};
        if (move) {
            // Capture is owned before clear, so overlapping moves are exact.
            for (int y = source.position.y; y < source.position.y + source.size.y; ++y)
                for (int x = source.position.x; x < source.position.x + source.size.x; ++x)
                    std::memcpy(p + (y * kWidth + x) * kTuple, empty, kTuple);
        }
        for (int y = 0; y < destination.size.y; ++y)
            std::memcpy(p + ((destination.position.y + y) * kWidth + destination.position.x) * kTuple,
                clipboard.ptr() + y * destination.size.x * kTuple, destination.size.x * kTuple);
        PackedInt32Array indices;
        PackedByteArray desired;
        // One bounded native value operation. Never one Web call per cell.
        const Rect2i bounds = move ? source.merge(destination) : destination;
        const int64_t count = static_cast<int64_t>(bounds.size.x) * bounds.size.y;
        indices.resize(count); desired.resize(count * kTuple);
        int64_t i = 0;
        for (int y = bounds.position.y; y < bounds.position.y + bounds.size.y; ++y) {
            for (int x = bounds.position.x; x < bounds.position.x + bounds.size.x; ++x, ++i) {
                indices.ptrw()[i] = y * kWidth + x;
                std::memcpy(desired.ptrw() + i * kTuple, p + (y * kWidth + x) * kTuple, kTuple);
            }
        }
        return plan_patch(cells, indices, desired);
    }

    Dictionary capture_cells(CyberNativeCellWorld* adapter) const {
        if (!adapter || !supported(*adapter)) return result(false, "unsupported_or_failed_world");
        try {
            PackedByteArray cells;
            cells.resize(kCells * kTuple);
            uint8_t* p = cells.ptrw();
            for (int i = 0; i < kCells; ++i) read_tuple(*adapter->world_, i, p + i * kTuple);
            Dictionary out = result(true);
            out["cells"] = cells;
            out["revision"] = static_cast<int64_t>(adapter->revision_);
            out["tick"] = adapter->get_tick_index();
            return out;
        } catch (const std::exception& e) { return result(false, String(e.what())); }
    }

    Dictionary apply_patch(CyberNativeCellWorld* adapter, const PackedInt32Array& indices,
                           const PackedByteArray& before, const PackedByteArray& after,
                           int64_t expected_revision, int64_t expected_tick) const {
        if (!adapter || !supported(*adapter)) return result(false, "unsupported_or_failed_world");
        if (expected_revision != static_cast<int64_t>(adapter->revision_) || expected_tick != adapter->get_tick_index())
            return result(false, "stale_native_revision_or_tick");
        const int64_t n = indices.size();
        if (n < 1 || n > kMaxPatch || before.size() != n * kTuple || after.size() != n * kTuple)
            return result(false, "invalid_patch_size");
        auto& world = *adapter->world_;
        const auto* ip = indices.ptr();
        const auto* bp = before.ptr();
        const auto* ap = after.ptr();
        uint8_t observed[kTuple];
        bool any_change = false;
        for (int64_t i = 0; i < n; ++i) {
            if (ip[i] < 0 || ip[i] >= kCells || (i > 0 && ip[i] <= ip[i - 1]))
                return result(false, "indices_must_be_unique_sorted_in_bounds");
            if (!valid_tuple(bp + i * kTuple) || !valid_tuple(ap + i * kTuple))
                return result(false, "invalid_cell_tuple");
            read_tuple(world, ip[i], observed);
            if (std::memcmp(observed, bp + i * kTuple, kTuple) != 0)
                return result(false, "before_tuple_conflict");
            if (std::memcmp(observed, ap + i * kTuple, kTuple) == 0) continue;
            // Do not mutate even the hidden stored cells under a live body.
            if (world.transient_obstacle_at(ip[i] % kWidth, ip[i] / kWidth) != 0U)
                return result(false, "body_occupancy_conflict");
            any_change = true;
        }
        if (!any_change) return result(false, "no_effect");
        bool mutation_started = false;
        try {
            // All validation and expected thermal storage allocation precede
            // semantic writes. No whole-world import or per-cell Godot calls.
            world.reserve_temperature_region({0, 0, kWidth, kWidth});
            const uint64_t hard_before = world.hard_surface_revision();
            mutation_started = true;
            for (int64_t i = 0; i < n; ++i) {
                const auto* p = ap + i * kTuple;
                const int x = ip[i] % kWidth, y = ip[i] / kWidth;
                // false is also the native setter's no-change return. A
                // temperature-only edit must still proceed and verify tuples.
                (void)world.set_cell_state(x, y, static_cast<cybersand::Material>(p[0]), p[1], p[2]);
                world.set_temperature(x, y, std::bit_cast<int16_t>(static_cast<uint16_t>(p[3] | (p[4] << 8U))));
                read_tuple(world, ip[i], observed);
                if (std::memcmp(observed, p, kTuple) != 0)
                    throw std::runtime_error("native_tuple_write_refused");
            }
            ++adapter->revision_;
            if (world.hard_surface_revision() != hard_before) ++adapter->hard_surface_revision_;
            Dictionary out = result(true);
            out["cells_changed"] = n;
            out["revision"] = static_cast<int64_t>(adapter->revision_);
            out["tick"] = adapter->get_tick_index();
            return out;
        } catch (const std::exception& e) {
            if (mutation_started) {
                ++adapter->revision_;
                ++adapter->hard_surface_revision_;
            }
            return result(false, String(e.what()), mutation_started);
        }
    }

protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("extract_rectangle", "cells", "rectangle"), &SandfallEditBridge::extract_rectangle);
        ClassDB::bind_method(D_METHOD("selection_patch", "cells", "source", "destination", "clipboard", "move"), &SandfallEditBridge::selection_patch);
        ClassDB::bind_method(D_METHOD("plan_patch", "current", "indices", "desired"), &SandfallEditBridge::plan_patch);
        ClassDB::bind_method(D_METHOD("repeated_tuple", "value", "count"), &SandfallEditBridge::repeated_tuple);
        ClassDB::bind_method(D_METHOD("catalogue"), &SandfallEditBridge::catalogue);
        ClassDB::bind_method(D_METHOD("validate_cells", "cells"), &SandfallEditBridge::validate_cells);
        ClassDB::bind_method(D_METHOD("capture_cells", "world"), &SandfallEditBridge::capture_cells);
        ClassDB::bind_method(D_METHOD("apply_patch", "world", "indices", "before", "after", "expected_revision", "expected_tick"), &SandfallEditBridge::apply_patch);
    }
};
} // namespace godot
