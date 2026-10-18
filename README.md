# Should Lumetta Partner with Olist? A SQL Exploration

## Business question
Lumetta is considering a partnership with Olist, a Brazilian e-commerce marketplace. This project uses SQL to answer one question for the CFO, the Head of Customer Experience and the Growth Lead: **is Olist a viable channel for Lumetta, and if so, where and in which categories should a pilot start?**

## Dataset
**Brazilian E-Commerce Public Dataset by Olist** (about 100k orders, 2016–2018, 9 related tables: customers, geolocation, orders, order_items, order_payments, order_reviews, products, sellers, product_category_translation).
Source: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

> The raw CSVs are not included in this repo. Download them from the link above.

## Tools
- **MySQL Workbench**: schema setup, data import and all queries
- **Tableau**: dashboards (category fit, delivery performance)
- **GitHub**: version control and documentation

## Key findings

1. **Electronics is a sizeable segment.** Across Olist's 99,441 orders (Sept 2016 – Oct 2018), the electronics categories account for 15,311 orders and about 1.89M in item revenue, spread over 485 sellers, with an average item price of 110.19.
2. **Delivery is reliable, but slightly above the guardrail.** 97.7% of electronics orders are delivered, and 8.4% of those arrive after the estimated date. That is just over the ~8% late-rate threshold I set for a partnership.
3. **Lateness is what drives bad reviews.** Orders delivered on time average 4.21 stars, with 10.8% negative reviews. For orders 1–3 days late, negative reviews rise to 25.5%. For orders more than 7 days late, the average drops to 1.66 stars and 80.4% of reviews are negative. Even a small delay costs customer satisfaction, which makes delivery performance the central operational risk.
4. **Higher-value items are riskier.** For items priced at 500 or more (522 orders), the average rating falls to 3.93 (vs 4.03 for all electronics), negative reviews rise to 18.8% (vs 15.5%) and the late rate reaches 9.8% (vs 8.4%). Expensive products have less tolerance for delivery problems.
5. **Customers pay by card, in installments.** Credit cards make up 70.4% of electronics payments, with 2.72 installments on average, and boleto (bank slip) is the second method at 23.1%. A partnership would need to support both.
6. **[Seller concentration]** The top 5 sellers hold [X]% of revenue in [category], so the channel depends on very few sellers. *(Fill in from your seller-concentration query, or delete this line.)*

**Verdict:** a conditional "yes". Run a limited pilot in Computers and Tablets, starting in SP and expanding to MG and PR, with a late-delivery guardrail below ~8%.

## How the queries are organised
| File | Contents |
|---|---|
| `olist_queries.sql` | Queries 1–14, grouped by theme |
| `v_order_item_base` | A reusable view that joins orders, items, products, sellers and reviews, so later queries stay short |

**Query groups**
- **Q1–Q[x]: Data exploration**: row counts, date ranges, nulls, duplicates
- **Q[x]–Q[x]: Category analysis**: orders, revenue and price by category
- **Q[x]–Q[x]: Delivery & reviews**: delays, review scores, delay by state and month
- **Q[x]–Q[14]: Sellers & geography**: seller concentration, orders by state

## How to reproduce
1. Download the dataset from Kaggle (link above).
2. Run `olist_schema_mysql.sql` in MySQL Workbench to create the tables.
3. Import the CSVs with the Table Data Import Wizard.
4. Run `olist_queries.sql` (create the view `v_order_item_base` first).

## Author
Fatma, data analysis bootcamp, October 2026
