"""
Flask application factory (ECS / RDS edition).

Schema is managed by Alembic (see migrations/), NOT by the app — importing or
starting the app performs no DDL. Sessions are request-scoped and cleaned up
automatically on app-context teardown.
"""

import os
import logging
from datetime import datetime

import click
from flask import Flask, jsonify, request, g
from werkzeug.exceptions import BadRequest
from sqlalchemy import select, func
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import sessionmaker, scoped_session

from models import Base, Product, Order, SEED_PRODUCTS, create_db_engine

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


def create_app(engine=None) -> Flask:
    """Construct the Flask app. Pass an engine to inject one (e.g. in tests)."""
    app = Flask(__name__)

    app.config["APP_NAME"] = os.getenv("APP_NAME", "legacy-api")
    app.config["APP_VERSION"] = os.getenv("APP_VERSION", "2.0.0")
    app.config["ENVIRONMENT"] = os.getenv("ENVIRONMENT", "production")

    engine = engine or create_db_engine()
    # scoped_session keys sessions to the request/thread; .remove() on teardown
    # returns the connection to the pool and prevents leaks.
    Session = scoped_session(sessionmaker(bind=engine, expire_on_commit=False, future=True))

    app.extensions["engine"] = engine
    app.extensions["session"] = Session

    @app.teardown_appcontext
    def _remove_session(exception=None):
        Session.remove()

    def db():
        if "db" not in g:
            g.db = Session()
        return g.db

    # ------------------------------------------------------------- routes
    @app.get("/health")
    def health():
        db_ok = True
        try:
            with engine.connect() as conn:
                conn.exec_driver_sql("SELECT 1")
        except SQLAlchemyError:
            db_ok = False
        return jsonify({
            "status": "healthy",
            "database": "connected" if db_ok else "unavailable",
            "timestamp": datetime.utcnow().isoformat(),
            "service": app.config["APP_NAME"],
            "version": app.config["APP_VERSION"],
            "environment": app.config["ENVIRONMENT"],
        }), 200

    @app.get("/api/v1/products")
    def get_products():
        products = db().scalars(select(Product).order_by(Product.id)).all()
        return jsonify({"products": [p.to_dict() for p in products], "count": len(products)}), 200

    @app.get("/api/v1/products/<int:product_id>")
    def get_product(product_id):
        product = db().get(Product, product_id)
        if not product:
            return jsonify({"error": "Product not found"}), 404
        return jsonify(product.to_dict()), 200

    @app.get("/api/v1/orders")
    def get_orders():
        orders = db().scalars(select(Order).order_by(Order.id)).all()
        return jsonify({"orders": [o.to_dict() for o in orders], "count": len(orders)}), 200

    @app.post("/api/v1/orders")
    def create_order():
        session = db()
        try:
            data = request.get_json(silent=True)
            if not data:
                raise BadRequest("No JSON data provided")

            product_id = data.get("product_id")
            quantity = data.get("quantity", 1)
            if not product_id:
                raise BadRequest("product_id is required")
            if not isinstance(quantity, int) or quantity < 1:
                raise BadRequest("quantity must be a positive integer")

            # Lock the product row so concurrent orders can't oversell stock.
            product = session.get(Product, product_id, with_for_update=True)
            if not product:
                return jsonify({"error": "Product not found"}), 404
            if quantity > product.stock:
                return jsonify({"error": "Insufficient stock"}), 400

            order = Order(
                product_id=product.id,
                product_name=product.name,
                quantity=quantity,
                total_price=round(product.price * quantity, 2),
                created_at=datetime.utcnow(),
            )
            product.stock -= quantity
            session.add(order)
            session.commit()
            logger.info("Order created: %s", order.id)
            return jsonify(order.to_dict()), 201

        except BadRequest as exc:
            return jsonify({"error": str(exc)}), 400
        except SQLAlchemyError as exc:
            session.rollback()
            logger.error("Error creating order: %s", exc)
            return jsonify({"error": "Internal server error"}), 500

    @app.get("/api/v1/stats")
    def get_stats():
        session = db()
        total_products = session.scalar(select(func.count()).select_from(Product))
        total_orders = session.scalar(select(func.count()).select_from(Order))
        total_revenue = session.scalar(select(func.coalesce(func.sum(Order.total_price), 0.0)))
        return jsonify({
            "total_products": total_products,
            "total_orders": total_orders,
            "total_revenue": round(float(total_revenue), 2),
            "timestamp": datetime.utcnow().isoformat(),
        }), 200

    @app.errorhandler(404)
    def not_found(error):
        return jsonify({"error": "Not found"}), 404

    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({"error": "Internal server error"}), 500

    # --------------------------------------------------------------- CLI
    @app.cli.command("seed")
    def seed():
        """Idempotently insert the baseline product catalogue."""
        session = Session()
        try:
            if session.scalar(select(func.count()).select_from(Product)):
                click.echo("Products already present; nothing to seed.")
                return
            session.add_all([Product(**p) for p in SEED_PRODUCTS])
            session.commit()
            click.echo(f"Seeded {len(SEED_PRODUCTS)} products.")
        finally:
            Session.remove()

    @app.cli.command("create-all")
    def create_all():
        """Create tables directly (dev/test convenience; prod uses Alembic)."""
        Base.metadata.create_all(engine)
        click.echo("Tables created.")

    return app


if __name__ == "__main__":
    create_app().run(host="0.0.0.0", port=5000, debug=False)
