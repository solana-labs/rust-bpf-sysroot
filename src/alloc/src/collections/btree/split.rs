use super::map::MIN_LEN;
use super::node::{ForceResult::*, Root};
use super::search::{search_node, SearchResult::*};
use core::borrow::Borrow;

impl<K, V> Root<K, V> {
    pub fn split_off<Q: ?Sized + Ord>(&mut self, right_root: &mut Self, key: &Q)
    where
        K: Borrow<Q>,
    {
        debug_assert!(right_root.height() == 0);
        debug_assert!(right_root.len() == 0);

        let left_root = self;
        for _ in 0..left_root.height() {
            right_root.push_internal_level();
        }

        {
            let mut left_node = left_root.borrow_mut();
            let mut right_node = right_root.borrow_mut();

            loop {
                let mut split_edge = match search_node(left_node, key) {
                    // key is going to the right tree
                    Found(kv) => kv.left_edge(),
                    GoDown(edge) => edge,
                };

                split_edge.move_suffix(&mut right_node);

                match (split_edge.force(), right_node.force()) {
                    (Internal(edge), Internal(node)) => {
                        left_node = edge.descend();
                        right_node = node.first_edge().descend();
                    }
                    (Leaf(_), Leaf(_)) => {
                        break;
                    }
                    _ => unreachable!(),
                }
            }
        }

        left_root.fix_right_border();
        right_root.fix_left_border();
    }

    /// Removes empty levels on the top, but keeps an empty leaf if the entire tree is empty.
    fn fix_top(&mut self) {
        while self.height() > 0 && self.len() == 0 {
            self.pop_internal_level();
        }
    }

    fn fix_right_border(&mut self) {
        self.fix_top();

        {
            let mut cur_node = self.borrow_mut();

            while let Internal(node) = cur_node.force() {
                let mut last_kv = node.last_kv().consider_for_balancing();

                if last_kv.can_merge() {
                    cur_node = last_kv.merge(None).into_node();
                } else {
                    let right_len = last_kv.right_child_len();
                    // `MIN_LEN + 1` to avoid readjust if merge happens on the next level.
                    if right_len < MIN_LEN + 1 {
                        last_kv.bulk_steal_left(MIN_LEN + 1 - right_len);
                    }
                    cur_node = last_kv.into_right_child();
                }
            }
        }

        self.fix_top();
    }

    /// The symmetric clone of `fix_right_border`.
    fn fix_left_border(&mut self) {
        self.fix_top();

        {
            let mut cur_node = self.borrow_mut();

            while let Internal(node) = cur_node.force() {
                let mut first_kv = node.first_kv().consider_for_balancing();

                if first_kv.can_merge() {
                    cur_node = first_kv.merge(None).into_node();
                } else {
                    let left_len = first_kv.left_child_len();
                    // `MIN_LEN + 1` to avoid readjust if merge happens on the next level.
                    if left_len < MIN_LEN + 1 {
                        first_kv.bulk_steal_right(MIN_LEN + 1 - left_len);
                    }
                    cur_node = first_kv.into_left_child();
                }
            }
        }

        self.fix_top();
    }
}
