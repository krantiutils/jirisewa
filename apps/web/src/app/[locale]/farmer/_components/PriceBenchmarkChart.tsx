"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from "recharts";
import type { PriceBenchmark } from "../analytics-actions";

export function PriceBenchmarkChart({
  data,
  myPriceLabel,
  marketPriceLabel,
}: {
  data: PriceBenchmark[];
  myPriceLabel: string;
  marketPriceLabel: string;
}) {
  const chartData = data.map((d) => ({
    name: d.category_name_en,
    myPrice: Number(Number(d.my_avg_price).toFixed(1)),
    marketPrice: Number(Number(d.market_avg_price).toFixed(1)),
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={chartData}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
        <XAxis
          dataKey="name"
          tick={{ fontSize: 12, fill: "#6b7280" }}
          tickLine={false}
          axisLine={false}
        />
        <YAxis
          tick={{ fontSize: 12, fill: "#6b7280" }}
          tickLine={false}
          axisLine={false}
          width={50}
        />
        <Tooltip
          contentStyle={{
            borderRadius: "8px",
            border: "1px solid #e5e7eb",
            fontSize: "14px",
          }}
          formatter={(value) => [`NPR ${value ?? 0}/kg`]}
        />
        <Legend />
        <Bar
          name={myPriceLabel}
          dataKey="myPrice"
          fill="#059669"
          radius={[4, 4, 0, 0]}
          barSize={20}
        />
        <Bar
          name={marketPriceLabel}
          dataKey="marketPrice"
          fill="#94a3b8"
          radius={[4, 4, 0, 0]}
          barSize={20}
        />
      </BarChart>
    </ResponsiveContainer>
  );
}
